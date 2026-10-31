import 'package:flutter_test/flutter_test.dart';
import 'package:medmais/features/medications/domain/medication.dart';

void main() {
  group('MedicationDose', () {
    test('accepts the supported units', () {
      for (final unit in DoseUnit.values) {
        expect(MedicationDose(amount: 1, unit: unit).unit.symbol, isNotEmpty);
      }
    });

    test('rejects non-positive and non-finite amounts', () {
      for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          () => MedicationDose(amount: amount, unit: DoseUnit.unit),
          throwsArgumentError,
        );
      }
    });
  });

  group('MedicationSchedule', () {
    final times = [
      ScheduledTime(hour: 8, minute: 0),
      ScheduledTime(hour: 20, minute: 30),
    ];

    test('recognizes a schedule for every day', () {
      final schedule = MedicationSchedule(
        daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
        times: times,
      );

      expect(schedule.isEveryDay, isTrue);
      expect(schedule.times, hasLength(2));
    });

    test('supports selected weekdays', () {
      final schedule = MedicationSchedule(
        daysOfWeek: {DateTime.monday, DateTime.friday},
        times: [times.first],
      );

      expect(schedule.isEveryDay, isFalse);
      expect(schedule.daysOfWeek, {DateTime.monday, DateTime.friday});
    });

    test('rejects empty, invalid, or duplicate schedule values', () {
      expect(
        () => MedicationSchedule(daysOfWeek: {}, times: times),
        throwsArgumentError,
      );
      expect(
        () => MedicationSchedule(daysOfWeek: {8}, times: times),
        throwsArgumentError,
      );
      expect(
        () => MedicationSchedule(daysOfWeek: {1}, times: []),
        throwsArgumentError,
      );
      expect(
        () => MedicationSchedule(
          daysOfWeek: {1},
          times: [times.first, times.first],
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid clock times', () {
      expect(() => ScheduledTime(hour: 24, minute: 0), throwsArgumentError);
      expect(() => ScheduledTime(hour: 8, minute: 60), throwsArgumentError);
    });
  });

  group('Medication', () {
    final createdAt = DateTime(2026, 10, 24);
    final schedule = MedicationSchedule(
      daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
      times: [ScheduledTime(hour: 8, minute: 0)],
    );

    test('requires identifying details and at least one schedule', () {
      expect(
        () => Medication(
          id: 'm1',
          name: ' ',
          dose: MedicationDose(amount: 1, unit: DoseUnit.unit),
          schedules: [schedule],
          createdAt: createdAt,
        ),
        throwsArgumentError,
      );
      expect(
        () => Medication(
          id: 'm1',
          name: 'Medicine',
          dose: MedicationDose(amount: 1, unit: DoseUnit.unit),
          schedules: [],
          createdAt: createdAt,
        ),
        throwsArgumentError,
      );
    });

    test('deactivates without removing medication data', () {
      final medication = Medication(
        id: 'm1',
        name: ' Medicine ',
        dose: MedicationDose(amount: 1, unit: DoseUnit.unit),
        schedules: [schedule],
        createdAt: createdAt,
      );

      final deactivated = medication.deactivate(at: DateTime(2026, 10, 25));

      expect(medication.name, 'Medicine');
      expect(medication.isActive, isTrue);
      expect(deactivated.isActive, isFalse);
      expect(deactivated.id, medication.id);
      expect(deactivated.schedules, medication.schedules);
      expect(
        deactivated.deactivate(at: DateTime(2026, 10, 26)),
        same(deactivated),
      );
    });

    test('does not allow deactivation before creation', () {
      final medication = Medication(
        id: 'm1',
        name: 'Medicine',
        dose: MedicationDose(amount: 1, unit: DoseUnit.unit),
        schedules: [schedule],
        createdAt: createdAt,
      );

      expect(
        () => medication.deactivate(at: DateTime(2026, 10, 23)),
        throwsArgumentError,
      );
    });
  });
}
