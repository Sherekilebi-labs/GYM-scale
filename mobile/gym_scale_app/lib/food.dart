import 'constants.dart';

class Food {
  const Food({
    this.id,
    required this.name,
    required this.iconId,
    required this.colorRgb,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.fatPer100g,
    required this.carbsPer100g,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final int? id;
  final String name;
  final int iconId;
  final int colorRgb;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double fatPer100g;
  final double carbsPer100g;
  final int createdAtMs;
  final int updatedAtMs;

  Food copyWith({
    int? id,
    String? name,
    int? iconId,
    int? colorRgb,
    double? caloriesPer100g,
    double? proteinPer100g,
    double? fatPer100g,
    double? carbsPer100g,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return Food(
      id: id ?? this.id,
      name: name ?? this.name,
      iconId: iconId ?? this.iconId,
      colorRgb: colorRgb ?? this.colorRgb,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'icon_id': iconId,
      'color_rgb': colorRgb,
      'calories_per_100g': caloriesPer100g,
      'protein_per_100g': proteinPer100g,
      'fat_per_100g': fatPer100g,
      'carbs_per_100g': carbsPer100g,
      'created_at_ms': createdAtMs,
      'updated_at_ms': updatedAtMs,
    };
  }

  static Food fromMap(Map<String, Object?> map) {
    return Food(
      id: map['id'] as int?,
      name: map['name'] as String,
      iconId: map['icon_id'] as int,
      colorRgb: map['color_rgb'] as int,
      caloriesPer100g: (map['calories_per_100g'] as num).toDouble(),
      proteinPer100g: (map['protein_per_100g'] as num).toDouble(),
      fatPer100g: (map['fat_per_100g'] as num).toDouble(),
      carbsPer100g: (map['carbs_per_100g'] as num).toDouble(),
      createdAtMs: map['created_at_ms'] as int,
      updatedAtMs: map['updated_at_ms'] as int,
    );
  }

  static Food defaults({required String name}) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int index = now % foodPalette.length;
    return Food(
      name: name,
      iconId: index,
      colorRgb: foodPalette[index].toARGB32() & 0x00ffffff,
      caloriesPer100g: 0,
      proteinPer100g: 0,
      fatPer100g: 0,
      carbsPer100g: 0,
      createdAtMs: now,
      updatedAtMs: now,
    );
  }
}
