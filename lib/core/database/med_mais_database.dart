import 'package:sqflite/sqflite.dart';

class MedMaisDatabase {
  MedMaisDatabase._(this._database);

  static const fileName = 'medmais.db';
  static const schemaVersion = 1;

  final Database _database;

  Database get executor => _database;

  static Future<MedMaisDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final databasePath = path ?? '${await getDatabasesPath()}/$fileName';
    final database = await (factory ?? databaseFactory).openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
      ),
    );
    return MedMaisDatabase._(database);
  }

  Future<void> close() => _database.close();

  static Future<void> _createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE medications (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        dose_amount REAL NOT NULL CHECK (dose_amount > 0),
        dose_unit TEXT NOT NULL CHECK (dose_unit IN ('unit', 'milligram', 'milliliter')),
        created_at INTEGER NOT NULL,
        deactivated_at INTEGER,
        CHECK (deactivated_at IS NULL OR deactivated_at >= created_at)
      )
    ''');

    await database.execute('''
      CREATE TABLE medication_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id TEXT NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
        schedule_index INTEGER NOT NULL,
        UNIQUE (medication_id, schedule_index)
      )
    ''');

    await database.execute('''
      CREATE TABLE schedule_days (
        schedule_id INTEGER NOT NULL REFERENCES medication_schedules(id) ON DELETE CASCADE,
        weekday INTEGER NOT NULL CHECK (weekday BETWEEN 1 AND 7),
        PRIMARY KEY (schedule_id, weekday)
      )
    ''');

    await database.execute('''
      CREATE TABLE schedule_times (
        schedule_id INTEGER NOT NULL REFERENCES medication_schedules(id) ON DELETE CASCADE,
        hour INTEGER NOT NULL CHECK (hour BETWEEN 0 AND 23),
        minute INTEGER NOT NULL CHECK (minute BETWEEN 0 AND 59),
        PRIMARY KEY (schedule_id, hour, minute)
      )
    ''');

    await database.execute('''
      CREATE TABLE medication_intakes (
        id TEXT PRIMARY KEY,
        medication_id TEXT NOT NULL REFERENCES medications(id) ON DELETE RESTRICT,
        scheduled_at INTEGER NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('pending', 'taken', 'notTaken')),
        recorded_at INTEGER,
        CHECK (
          (status = 'pending' AND recorded_at IS NULL) OR
          (status != 'pending' AND recorded_at IS NOT NULL)
        )
      )
    ''');

    await database.execute(
      'CREATE INDEX medication_intakes_scheduled_at '
      'ON medication_intakes(scheduled_at)',
    );
    await database.execute(
      'CREATE INDEX medication_intakes_medication_id '
      'ON medication_intakes(medication_id)',
    );
  }
}
