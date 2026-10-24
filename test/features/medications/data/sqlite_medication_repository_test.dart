import 'package:flutter_test/flutter_test.dart';
import 'package:medmais/core/database/med_mais_database.dart';
import 'package:medmais/features/medications/data/sqlite_medication_repository.dart';
import 'package:medmais/features/medications/domain/medication.dart';
import 'package:medmais/features/medications/domain/medication_intake.dart';
import 'package:medmais/features/history/data/sqlite_intake_history_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late MedMaisDatabase database;
  late SqliteMedicationRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await MedMaisDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = SqliteMedicationRepository(database);
  });

  tearDown(() => database.close());

  test('round-trips medication dose, weekdays, and multiple times', () async {
    final medication = _medication(
      schedules: [
        MedicationSchedule(
          daysOfWeek: {DateTime.monday, DateTime.friday},
          times: [
            ScheduledTime(hour: 8, minute: 0),
            ScheduledTime(hour: 20, minute: 30),
          ],
        ),
        MedicationSchedule(
          daysOfWeek: {DateTime.sunday},
          times: [ScheduledTime(hour: 12, minute: 15)],
        ),
      ],
      dose: MedicationDose(amount: 2.5, unit: DoseUnit.milliliter),
      createdAt: DateTime(2026, 10, 24, 12, 30),
    );

    await repository.save(medication);
    final result = await repository.getById(medication.id);

    expect(result, isNotNull);
    expect(result!.name, medication.name);
    expect(result.dose.amount, 2.5);
    expect(result.dose.unit, DoseUnit.milliliter);
    expect(result.createdAt.isAtSameMomentAs(medication.createdAt), isTrue);
    expect(result.schedules, hasLength(2));
    expect(result.schedules.first.daysOfWeek, {
      DateTime.monday,
      DateTime.friday,
    });
    expect(result.schedules.first.times, [
      ScheduledTime(hour: 8, minute: 0),
      ScheduledTime(hour: 20, minute: 30),
    ]);
    expect(result.schedules.last.times, [ScheduledTime(hour: 12, minute: 15)]);
  });

  test('updates medication without deleting its intake history', () async {
    final medication = _medication();
    await repository.save(medication);
    final history = SqliteIntakeHistoryRepository(database);
    final intake = MedicationIntake(
      id: 'intake-1',
      medicationId: medication.id,
      scheduledAt: DateTime(2026, 10, 25, 8),
    );
    await history.save(intake);

    final updated = Medication(
      id: medication.id,
      name: 'Updated medication',
      dose: MedicationDose(amount: 500, unit: DoseUnit.milligram),
      schedules: [
        MedicationSchedule(
          daysOfWeek: {DateTime.tuesday},
          times: [ScheduledTime(hour: 9, minute: 30)],
        ),
      ],
      createdAt: medication.createdAt,
    );
    await repository.save(updated);

    expect(
      (await repository.getById(medication.id))!.name,
      'Updated medication',
    );
    final intakes = await history.getBetween(
      startInclusive: DateTime(2026, 10, 25),
      endExclusive: DateTime(2026, 10, 26),
    );
    expect(intakes, hasLength(1));
    expect(intakes.single.id, intake.id);
    expect(intakes.single.status, intake.status);
    expect(
      intakes.single.scheduledAt.isAtSameMomentAs(intake.scheduledAt),
      isTrue,
    );
  });

  test(
    'keeps deactivated medication stored and excludes it by default',
    () async {
      final medication = _medication();
      final deactivated = medication.deactivate(at: DateTime(2026, 10, 25));

      await repository.save(deactivated);

      expect(await repository.getAll(), isEmpty);
      final allMedications = await repository.getAll(includeInactive: true);
      expect(allMedications, hasLength(1));
      expect(allMedications.single.id, deactivated.id);
      expect(allMedications.single.isActive, isFalse);
      expect((await repository.getById(medication.id))!.isActive, isFalse);
    },
  );

  test(
    'rolls back a medication update if its schedules cannot be saved',
    () async {
      final medication = _medication();
      await repository.save(medication);

      await database.executor.execute('''
        CREATE TRIGGER reject_schedule BEFORE INSERT ON medication_schedules
        BEGIN
          SELECT RAISE(ABORT, 'test transaction rollback');
        END
      ''');
      final updatedMedication = Medication(
        id: medication.id,
        name: 'Should not persist',
        dose: medication.dose,
        schedules: medication.schedules,
        createdAt: medication.createdAt,
      );

      await expectLater(
        repository.save(updatedMedication),
        throwsA(isA<Exception>()),
      );
      expect((await repository.getById(medication.id))!.name, medication.name);
    },
  );
}

Medication _medication({
  List<MedicationSchedule>? schedules,
  MedicationDose? dose,
  DateTime? createdAt,
}) => Medication(
  id: 'medication-1',
  name: 'Medication',
  dose: dose ?? MedicationDose(amount: 1, unit: DoseUnit.unit),
  schedules:
      schedules ??
      [
        MedicationSchedule(
          daysOfWeek: {
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
            DateTime.saturday,
            DateTime.sunday,
          },
          times: [ScheduledTime(hour: 8, minute: 0)],
        ),
      ],
  createdAt: createdAt ?? DateTime(2026, 10, 24),
);
