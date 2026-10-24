import 'package:sqflite/sqflite.dart';

import '../../../core/database/med_mais_database.dart';
import '../../../core/database/sqlite_date_time.dart';
import '../domain/medication.dart';
import 'medication_repository.dart';

class SqliteMedicationRepository implements MedicationRepository {
  SqliteMedicationRepository(MedMaisDatabase database)
    : _database = database.executor;

  final Database _database;

  @override
  Future<Medication?> getById(String id) async {
    final rows = await _database.query(
      'medications',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _loadMedication(rows.single);
  }

  @override
  Future<List<Medication>> getAll({bool includeInactive = false}) async {
    final rows = await _database.query(
      'medications',
      where: includeInactive ? null : 'deactivated_at IS NULL',
      orderBy: 'name COLLATE NOCASE, id',
    );
    return Future.wait(rows.map(_loadMedication));
  }

  @override
  Future<void> save(Medication medication) async {
    await _database.transaction((transaction) async {
      final values = {
        'name': medication.name,
        'dose_amount': medication.dose.amount,
        'dose_unit': medication.dose.unit.name,
        'created_at': dateTimeToSqlite(medication.createdAt),
        'deactivated_at': medication.deactivatedAt == null
            ? null
            : dateTimeToSqlite(medication.deactivatedAt!),
      };
      final existingRows = await transaction.query(
        'medications',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [medication.id],
        limit: 1,
      );
      if (existingRows.isEmpty) {
        await transaction.insert('medications', {
          'id': medication.id,
          ...values,
        });
      } else {
        await transaction.update(
          'medications',
          values,
          where: 'id = ?',
          whereArgs: [medication.id],
        );
      }

      await transaction.delete(
        'medication_schedules',
        where: 'medication_id = ?',
        whereArgs: [medication.id],
      );

      for (var index = 0; index < medication.schedules.length; index++) {
        final schedule = medication.schedules[index];
        final scheduleId = await transaction.insert('medication_schedules', {
          'medication_id': medication.id,
          'schedule_index': index,
        });
        final dayBatch = transaction.batch();
        for (final weekday in schedule.daysOfWeek) {
          dayBatch.insert('schedule_days', {
            'schedule_id': scheduleId,
            'weekday': weekday,
          });
        }
        final timeBatch = transaction.batch();
        for (final time in schedule.times) {
          timeBatch.insert('schedule_times', {
            'schedule_id': scheduleId,
            'hour': time.hour,
            'minute': time.minute,
          });
        }
        await dayBatch.commit(noResult: true);
        await timeBatch.commit(noResult: true);
      }
    });
  }

  Future<Medication> _loadMedication(Map<String, Object?> row) async {
    final medicationId = row['id']! as String;
    final scheduleRows = await _database.query(
      'medication_schedules',
      where: 'medication_id = ?',
      whereArgs: [medicationId],
      orderBy: 'schedule_index',
    );
    final schedules = <MedicationSchedule>[];

    for (final scheduleRow in scheduleRows) {
      final scheduleId = scheduleRow['id']! as int;
      final dayRows = await _database.query(
        'schedule_days',
        columns: ['weekday'],
        where: 'schedule_id = ?',
        whereArgs: [scheduleId],
        orderBy: 'weekday',
      );
      final timeRows = await _database.query(
        'schedule_times',
        where: 'schedule_id = ?',
        whereArgs: [scheduleId],
        orderBy: 'hour, minute',
      );
      schedules.add(
        MedicationSchedule(
          daysOfWeek: dayRows.map((day) => day['weekday']! as int).toSet(),
          times: timeRows
              .map(
                (time) => ScheduledTime(
                  hour: time['hour']! as int,
                  minute: time['minute']! as int,
                ),
              )
              .toList(),
        ),
      );
    }

    return Medication(
      id: medicationId,
      name: row['name']! as String,
      dose: MedicationDose(
        amount: (row['dose_amount']! as num).toDouble(),
        unit: DoseUnit.values.byName(row['dose_unit']! as String),
      ),
      schedules: schedules,
      createdAt: dateTimeFromSqlite(row['created_at']!),
      deactivatedAt: row['deactivated_at'] == null
          ? null
          : dateTimeFromSqlite(row['deactivated_at']!),
    );
  }
}
