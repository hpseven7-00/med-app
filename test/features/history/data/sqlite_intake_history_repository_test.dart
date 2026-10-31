import 'package:flutter_test/flutter_test.dart';
import 'package:medmais/core/database/med_mais_database.dart';
import 'package:medmais/features/history/data/sqlite_intake_history_repository.dart';
import 'package:medmais/features/medications/data/sqlite_medication_repository.dart';
import 'package:medmais/features/medications/domain/medication.dart';
import 'package:medmais/features/medications/domain/medication_intake.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late MedMaisDatabase database;
  late SqliteIntakeHistoryRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await MedMaisDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = SqliteIntakeHistoryRepository(database);
    await SqliteMedicationRepository(database).save(_medication);
  });

  tearDown(() => database.close());

  test('queries the half-open time range including pending intakes', () async {
    final first = MedicationIntake(
      id: 'intake-1',
      medicationId: _medication.id,
      scheduledAt: DateTime(2026, 10, 25, 8),
    );
    final second = MedicationIntake(
      id: 'intake-2',
      medicationId: _medication.id,
      scheduledAt: DateTime(2026, 10, 25, 12),
    );
    final outsideEnd = MedicationIntake(
      id: 'intake-3',
      medicationId: _medication.id,
      scheduledAt: DateTime(2026, 10, 26),
    );
    final subMillisecond = MedicationIntake(
      id: 'intake-4',
      medicationId: _medication.id,
      scheduledAt: DateTime(2026, 10, 25, 12, 0, 0, 0, 1),
    );
    await repository.save(first);
    await repository.save(
      second.recordTaken(at: DateTime(2026, 10, 25, 12, 5)),
    );
    await repository.save(outsideEnd);
    await repository.save(subMillisecond);

    final result = await repository.getBetween(
      startInclusive: DateTime(2026, 10, 25),
      endExclusive: DateTime(2026, 10, 26),
    );

    expect(result.map((intake) => intake.id), [
      'intake-1',
      'intake-2',
      'intake-4',
    ]);
    expect(result.first.status, IntakeStatus.pending);
    final taken = result.firstWhere((intake) => intake.id == 'intake-2');
    expect(taken.status, IntakeStatus.taken);
    expect(
      taken.recordedAt!.isAtSameMomentAs(DateTime(2026, 10, 25, 12, 5)),
      isTrue,
    );
  });

  test('rejects an empty or reversed range', () async {
    expect(
      repository.getBetween(
        startInclusive: DateTime(2026, 10, 25),
        endExclusive: DateTime(2026, 10, 25),
      ),
      throwsArgumentError,
    );
    expect(
      repository.getBetween(
        startInclusive: DateTime(2026, 10, 26),
        endExclusive: DateTime(2026, 10, 25),
      ),
      throwsArgumentError,
    );
  });

  test('requires an existing medication for intake records', () async {
    await expectLater(
      repository.save(
        MedicationIntake(
          id: 'orphan-intake',
          medicationId: 'missing-medication',
          scheduledAt: DateTime(2026, 10, 25, 8),
        ),
      ),
      throwsA(anything),
    );
  });
}

final _medication = Medication(
  id: 'medication-1',
  name: 'Medication',
  dose: MedicationDose(amount: 1, unit: DoseUnit.unit),
  schedules: [
    MedicationSchedule(
      daysOfWeek: {DateTime.monday},
      times: [ScheduledTime(hour: 8, minute: 0)],
    ),
  ],
  createdAt: DateTime(2026, 10, 24),
);
