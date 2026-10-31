import 'package:sqflite/sqflite.dart';

import '../../../core/database/med_mais_database.dart';
import '../../../core/database/sqlite_date_time.dart';
import '../../medications/domain/medication_intake.dart';
import '../domain/intake_history_repository.dart';

class SqliteIntakeHistoryRepository implements IntakeHistoryRepository {
  SqliteIntakeHistoryRepository(MedMaisDatabase database)
    : _database = database.executor;

  final Database _database;

  @override
  Future<MedicationIntake?> getById(String id) async {
    final rows = await _database.query(
      'medication_intakes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapIntake(rows.single);
  }

  @override
  Future<List<MedicationIntake>> getBetween({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    if (!startInclusive.isBefore(endExclusive)) {
      throw ArgumentError('startInclusive must be earlier than endExclusive.');
    }

    final rows = await _database.query(
      'medication_intakes',
      where: 'scheduled_at >= ? AND scheduled_at < ?',
      whereArgs: [
        dateTimeToSqlite(startInclusive),
        dateTimeToSqlite(endExclusive),
      ],
      orderBy: 'scheduled_at, id',
    );
    return rows.map(_mapIntake).toList();
  }

  @override
  Future<void> save(MedicationIntake intake) async {
    await _database.insert('medication_intakes', {
      'id': intake.id,
      'medication_id': intake.medicationId,
      'scheduled_at': dateTimeToSqlite(intake.scheduledAt),
      'status': intake.status.name,
      'recorded_at': intake.recordedAt == null
          ? null
          : dateTimeToSqlite(intake.recordedAt!),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  MedicationIntake _mapIntake(Map<String, Object?> row) => MedicationIntake(
    id: row['id']! as String,
    medicationId: row['medication_id']! as String,
    scheduledAt: dateTimeFromSqlite(row['scheduled_at']!),
    status: IntakeStatus.values.byName(row['status']! as String),
    recordedAt: row['recorded_at'] == null
        ? null
        : dateTimeFromSqlite(row['recorded_at']!),
  );
}
