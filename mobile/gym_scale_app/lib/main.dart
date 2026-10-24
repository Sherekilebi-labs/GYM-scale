import 'dart:async';
import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:flutter/material.dart';

import 'ble_scale_client.dart';
import 'constants.dart';
import 'food.dart';
import 'food_repository.dart';
import 'measurement_packet.dart';
import 'scale_state.dart';

void main() {
  runApp(const GymScaleApp());
}

class GymScaleApp extends StatelessWidget {
  const GymScaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GYM Scale',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff2f80ed),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const ScaleHomePage(),
    );
  }
}

class ScaleHomePage extends StatefulWidget {
  const ScaleHomePage({super.key});

  @override
  State<ScaleHomePage> createState() => _ScaleHomePageState();
}

class _ScaleHomePageState extends State<ScaleHomePage> with SingleTickerProviderStateMixin {
  final FoodRepository _repository = FoodRepository();
  final BleScaleClient _bleClient = BleScaleClient();
  final ScaleDisplayState _scaleState = ScaleDisplayState();
  final List<Food> _foods = <Food>[];
  late final AnimationController _blinkController;
  StreamSubscription<BleScaleSnapshot>? _bleSubscription;
  BleScaleSnapshot _bleSnapshot = const BleScaleSnapshot(status: BleScaleStatus.disconnected);
  int? _selectedFoodId;
  int _lastStableEvent = 0;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1080));
    _loadFoods();
    _bleSubscription = _bleClient.snapshots.listen(_handleBleSnapshot);
    _bleClient.start();
  }

  @override
  void dispose() {
    _bleSubscription?.cancel();
    _bleClient.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _loadFoods() async {
    final List<Food> foods = await _repository.loadFoods();
    final String? lastSelected = await _repository.loadSetting('selected_food_id');
    setState(() {
      _foods
        ..clear()
        ..addAll(foods);
      _selectedFoodId = int.tryParse(lastSelected ?? '');
      if (_selectedFoodId != null && !_foods.any((Food food) => food.id == _selectedFoodId)) {
        _selectedFoodId = null;
      }
    });
  }

  void _handleBleSnapshot(BleScaleSnapshot snapshot) {
    final MeasurementPacket? packet = snapshot.packet;
    setState(() {
      _bleSnapshot = snapshot;
      if (packet != null) {
        _scaleState.applyPacket(packet, DateTime.now());
        if (_scaleState.stableEvent != _lastStableEvent) {
          _lastStableEvent = _scaleState.stableEvent;
          _blinkController
            ..reset()
            ..forward();
        }
      }
    });
  }

  Food? get _selectedFood {
    for (final Food food in _foods) {
      if (food.id == _selectedFoodId) {
        return food;
      }
    }
    return null;
  }

  Future<void> _selectFood(Food food) async {
    setState(() => _selectedFoodId = food.id);
    if (food.id != null) {
      await _repository.saveSetting('selected_food_id', food.id.toString());
    }
  }

  Future<void> _showSearch() async {
    final Food? selected = await showModalBottomSheet<Food>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => FoodSearchSheet(foods: _foods),
    );
    if (selected != null) {
      await _selectFood(selected);
    }
  }

  Future<void> _showFoodForm({Food? food}) async {
    final Food? saved = await showModalBottomSheet<Food>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => FoodFormSheet(food: food),
    );
    if (saved == null) {
      return;
    }

    if (saved.id == null) {
      final Food inserted = await _repository.insertFood(saved);
      setState(() => _foods.add(inserted));
      await _selectFood(inserted);
    } else {
      await _repository.updateFood(saved);
      setState(() {
        final int index = _foods.indexWhere((Food existing) => existing.id == saved.id);
        if (index >= 0) {
          _foods[index] = saved;
        }
      });
    }
  }

  Future<void> _showFoodActions(Food food) async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );

    if (action == 'edit') {
      await _showFoodForm(food: food);
    } else if (action == 'delete') {
      await _confirmDelete(food);
    }
  }

  Future<void> _confirmDelete(Food food) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete food'),
          content: Text('Delete ${food.name}?'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
          ],
        );
      },
    );
    if (confirmed != true || food.id == null) {
      return;
    }
    await _repository.deleteFood(food.id!);
    setState(() {
      _foods.removeWhere((Food existing) => existing.id == food.id);
      if (_selectedFoodId == food.id) {
        _selectedFoodId = null;
      }
    });
  }

  String get _statusText {
    final MeasurementPacket? packet = _scaleState.latestPacket;
    if (_bleSnapshot.status == BleScaleStatus.permissionsNeeded) {
      return 'Bluetooth permission needed';
    }
    if (_bleSnapshot.status == BleScaleStatus.scanning) {
      return 'Scanning for GYM-Scale';
    }
    if (_bleSnapshot.status == BleScaleStatus.connecting) {
      return 'Connecting';
    }
    if (_bleSnapshot.status == BleScaleStatus.disconnected) {
      return 'Disconnected';
    }
    if (_bleSnapshot.status == BleScaleStatus.error) {
      return _bleSnapshot.message ?? 'Bluetooth error';
    }
    if (packet == null) {
      return 'Connected';
    }
    if (packet.flags.saturated) {
      return 'HX711 saturated';
    }
    if (packet.flags.overload) {
      return 'Overload';
    }
    if (packet.flags.warmingUp || !packet.flags.ready) {
      return 'Warming up';
    }
    if (_scaleState.frozen) {
      return 'Stable';
    }
    return 'Measuring';
  }

  @override
  Widget build(BuildContext context) {
    final Food? selectedFood = _selectedFood;
    return Scaffold(
      backgroundColor: const Color(0xfff5f3ed),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              children: <Widget>[
                ScaleDisplay(
                  text: _scaleState.latestPacket == null ? '--' : _scaleState.displayText,
                  unit: _scaleState.unitLabel,
                  animation: _blinkController,
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => setState(_scaleState.tare),
                        icon: const Icon(Icons.exposure_zero),
                        label: const Text('Tare'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => setState(_scaleState.toggleUnit),
                        icon: const Icon(Icons.swap_vert),
                        label: const Text('Mode'),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _statusText.toUpperCase(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xff394150)),
                  ),
                ),
                const Divider(color: Color(0xff111827), thickness: 2),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showSearch,
                        icon: const Icon(Icons.search),
                        label: const Text('Search'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showFoodForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FoodStrip(
                  foods: _foods,
                  selectedFoodId: _selectedFoodId,
                  onSelect: _selectFood,
                  onLongPress: _showFoodActions,
                ),
                if (selectedFood != null) ...<Widget>[
                  const SizedBox(height: 12),
                  NutritionPanel(food: selectedFood, grams: math.max(0, _scaleState.displayGrams)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ScaleDisplay extends StatelessWidget {
  const ScaleDisplay({
    super.key,
    required this.text,
    required this.unit,
    required this.animation,
  });

  final String text;
  final String unit;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfff7fbf3),
        border: Border.all(color: const Color(0xff111827), width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0xffd8ead3), spreadRadius: -5),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) {
              final double progress = animation.value;
              final bool dim = progress > 0 && ((progress * 6).floor()).isOdd;
              return Opacity(opacity: dim ? 0.08 : 1, child: child);
            },
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: SevenSegmentText(text: text),
            ),
          ),
          const SizedBox(height: 6),
          Text(unit.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class SevenSegmentText extends StatelessWidget {
  const SevenSegmentText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: text.characters.map((String char) {
        if (char == '.') {
          return Container(width: 9, height: 9, margin: const EdgeInsets.only(left: 2, top: 58), color: const Color(0xff06110b));
        }
        if (char == '-') {
          return const SegmentDigit(char: '-');
        }
        return SegmentDigit(char: char);
      }).toList(),
    );
  }
}

class SegmentDigit extends StatelessWidget {
  const SegmentDigit({super.key, required this.char});

  final String char;

  static const Map<String, String> segments = <String, String>{
    '0': 'abcdef',
    '1': 'bc',
    '2': 'abged',
    '3': 'abgcd',
    '4': 'fgbc',
    '5': 'afgcd',
    '6': 'afgecd',
    '7': 'abc',
    '8': 'abcdefg',
    '9': 'abfgcd',
    '-': 'g',
  };

  @override
  Widget build(BuildContext context) {
    final String on = segments[char] ?? '';
    return SizedBox(
      width: 44,
      height: 70,
      child: Stack(
        children: <Widget>[
          _segment('a', on, const Rect.fromLTWH(10, 2, 26, 5)),
          _segment('b', on, const Rect.fromLTWH(37, 8, 5, 25)),
          _segment('c', on, const Rect.fromLTWH(37, 38, 5, 25)),
          _segment('d', on, const Rect.fromLTWH(10, 64, 26, 5)),
          _segment('e', on, const Rect.fromLTWH(2, 38, 5, 25)),
          _segment('f', on, const Rect.fromLTWH(2, 8, 5, 25)),
          _segment('g', on, const Rect.fromLTWH(10, 32, 26, 5)),
        ],
      ),
    );
  }

  Widget _segment(String id, String on, Rect rect) {
    return Positioned.fromRect(
      rect: rect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: on.contains(id) ? const Color(0xff06110b) : const Color(0xffc9d6c4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class FoodStrip extends StatelessWidget {
  const FoodStrip({
    super.key,
    required this.foods,
    required this.selectedFoodId,
    required this.onSelect,
    required this.onLongPress,
  });

  final List<Food> foods;
  final int? selectedFoodId;
  final ValueChanged<Food> onSelect;
  final ValueChanged<Food> onLongPress;

  @override
  Widget build(BuildContext context) {
    if (foods.isEmpty) {
      return const SizedBox(height: 30, child: Align(alignment: Alignment.centerLeft, child: Text('No foods saved')));
    }
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: foods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final Food food = foods[index];
          final bool selected = food.id == selectedFoodId;
          return GestureDetector(
            onTap: () => onSelect(food),
            onLongPress: () => onLongPress(food),
            child: SizedBox(
              width: 36,
              height: 42,
              child: Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Color(0xff000000 | food.colorRgb),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xff111827), width: selected ? 3 : 2),
                  ),
                  child: Icon(foodIcon(food.iconId), color: Colors.white, size: 18),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class NutritionPanel extends StatelessWidget {
  const NutritionPanel({super.key, required this.food, required this.grams});

  final Food food;
  final double grams;

  @override
  Widget build(BuildContext context) {
    final double factor = grams / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(food.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _row('Calories:', '${_format(food.caloriesPer100g * factor)} kcal'),
        _row('Protein:', '${_format(food.proteinPer100g * factor)} g'),
        _row('Fat:', '${_format(food.fatPer100g * factor)} g'),
        _row('Carbohydrates:', '${_format(food.carbsPer100g * factor)} g'),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: const TextStyle(fontFamily: 'monospace', color: Color(0xff303846)))),
          SizedBox(
            width: 100,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  String _format(double value) {
    if (value >= 100) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  }
}

class FoodSearchSheet extends StatefulWidget {
  const FoodSearchSheet({super.key, required this.foods});

  final List<Food> foods;

  @override
  State<FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends State<FoodSearchSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final List<Food> matches = widget.foods.where((Food food) => food.name.toLowerCase().contains(query.toLowerCase())).toList();
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: Text('Search food', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          TextField(
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Food name'),
            onChanged: (String value) => setState(() => query = value),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: matches.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: Text('No matches'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: matches.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Food food = matches[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(0xff000000 | food.colorRgb),
                          child: Icon(foodIcon(food.iconId), color: Colors.white),
                        ),
                        title: Text(food.name),
                        onTap: () => Navigator.pop(context, food),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class FoodFormSheet extends StatefulWidget {
  const FoodFormSheet({super.key, this.food});

  final Food? food;

  @override
  State<FoodFormSheet> createState() => _FoodFormSheetState();
}

class _FoodFormSheetState extends State<FoodFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _fatController;
  late final TextEditingController _carbsController;
  late int _iconId;
  late int _colorRgb;

  @override
  void initState() {
    super.initState();
    final Food? food = widget.food;
    final Food defaults = Food.defaults(name: '');
    _nameController = TextEditingController(text: food?.name ?? '');
    _caloriesController = TextEditingController(text: _fieldText(food?.caloriesPer100g));
    _proteinController = TextEditingController(text: _fieldText(food?.proteinPer100g));
    _fatController = TextEditingController(text: _fieldText(food?.fatPer100g));
    _carbsController = TextEditingController(text: _fieldText(food?.carbsPer100g));
    _iconId = food?.iconId ?? defaults.iconId;
    _colorRgb = food?.colorRgb ?? defaults.colorRgb;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(widget.food == null ? 'Add food' : 'Edit food', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              maxLength: 31,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              validator: (String? value) => value == null || value.trim().isEmpty ? 'Food name is required' : null,
            ),
            const SizedBox(height: 10),
            const Text('Icon', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List<Widget>.generate(8, (int index) {
                return ChoiceChip(
                  label: Icon(foodIcon(index), size: 18),
                  selected: _iconId == index,
                  onSelected: (_) => setState(() => _iconId = index),
                );
              }),
            ),
            const SizedBox(height: 14),
            const Text('Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: foodPalette.map((Color color) {
                final int rgb = color.toARGB32() & 0x00ffffff;
                return GestureDetector(
                  onTap: () => setState(() => _colorRgb = rgb),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _colorRgb == rgb ? const Color(0xff111827) : Colors.transparent, width: 3),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool narrow = constraints.maxWidth < 360;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _numberField(_caloriesController, 'Calories', narrow),
                    _numberField(_proteinController, 'Protein', narrow),
                    _numberField(_fatController, 'Fat', narrow),
                    _numberField(_carbsController, 'Carbs', narrow),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.food == null ? 'Add food' : 'Save food'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label, bool narrow) {
    return SizedBox(
      width: narrow ? double.infinity : 160,
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (String? value) {
          if (value == null || value.trim().isEmpty) {
            return null;
          }
          final double? parsed = double.tryParse(value.trim());
          if (parsed == null || parsed < 0) {
            return 'Invalid value';
          }
          return null;
        },
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Food? existing = widget.food;
    Navigator.pop(
      context,
      Food(
        id: existing?.id,
        name: _nameController.text.trim(),
        iconId: _iconId,
        colorRgb: _colorRgb,
        caloriesPer100g: _parse(_caloriesController.text),
        proteinPer100g: _parse(_proteinController.text),
        fatPer100g: _parse(_fatController.text),
        carbsPer100g: _parse(_carbsController.text),
        createdAtMs: existing?.createdAtMs ?? now,
        updatedAtMs: now,
      ),
    );
  }

  String _fieldText(double? value) {
    if (value == null || value == 0) {
      return '';
    }
    return value.toString().replaceFirst(RegExp(r'\.0$'), '');
  }

  double _parse(String value) {
    return double.tryParse(value.trim()) ?? 0;
  }
}

IconData foodIcon(int id) {
  const List<IconData> icons = <IconData>[
    Icons.restaurant,
    Icons.eco,
    Icons.shopping_bag_outlined,
    Icons.favorite_border,
    Icons.bakery_dining,
    Icons.icecream_outlined,
    Icons.ramen_dining,
    Icons.water_drop_outlined,
  ];
  return icons[id % icons.length];
}
