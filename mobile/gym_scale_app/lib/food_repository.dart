import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'food.dart';

class FoodRepository {
  Database? _database;

  Future<Database> get database async {
    final Database? existing = _database;
    if (existing != null) {
      return existing;
    }
    final String dbPath = p.join(await getDatabasesPath(), 'gym_scale.db');
    final Database opened = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
CREATE TABLE foods(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  icon_id INTEGER NOT NULL,
  color_rgb INTEGER NOT NULL,
  calories_per_100g REAL NOT NULL DEFAULT 0,
  protein_per_100g REAL NOT NULL DEFAULT 0,
  fat_per_100g REAL NOT NULL DEFAULT 0,
  carbs_per_100g REAL NOT NULL DEFAULT 0,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
)
''');
        await db.execute('''
CREATE TABLE settings(
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
      },
    );
    _database = opened;
    return opened;
  }

  Future<List<Food>> loadFoods() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'foods',
      orderBy: 'created_at_ms ASC, id ASC',
    );
    return rows.map(Food.fromMap).toList();
  }

  Future<Food> insertFood(Food food) async {
    final Database db = await database;
    final int id = await db.insert('foods', food.toMap()..remove('id'));
    return food.copyWith(id: id);
  }

  Future<void> updateFood(Food food) async {
    final int? id = food.id;
    if (id == null) {
      throw ArgumentError('Cannot update food without id');
    }
    final Database db = await database;
    await db.update('foods', food.toMap()..remove('id'), where: 'id = ?', whereArgs: <Object>[id]);
  }

  Future<void> deleteFood(int id) async {
    final Database db = await database;
    await db.delete('foods', where: 'id = ?', whereArgs: <Object>[id]);
  }

  Future<String?> loadSetting(String key) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'settings',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object>[key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String;
  }

  Future<void> saveSetting(String key, String value) async {
    final Database db = await database;
    await db.insert(
      'settings',
      <String, Object>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
