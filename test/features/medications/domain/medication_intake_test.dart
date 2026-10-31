import 'package:flutter_test/flutter_test.dart';
import 'package:medmais/features/medications/domain/medication_intake.dart';

void main() {
  final scheduledAt = DateTime(2026, 10, 24, 8);

  MedicationIntake pendingIntake() => MedicationIntake(
    id: 'intake-1',
    medicationId: 'medication-1',
    scheduledAt: scheduledAt,
  );

  group('MedicationIntake', () {
    test('records taken only after explicit user action', () {
      final recordedAt = DateTime(2026, 10, 24, 8, 5);
      final intake = pendingIntake();
      final taken = intake.recordTaken(at: recordedAt);

      expect(intake.status, IntakeStatus.pending);
      expect(taken.status, IntakeStatus.taken);
      expect(taken.recordedAt, recordedAt);
    });

    test('records not taken only after explicit user action', () {
      final recordedAt = DateTime(2026, 10, 24, 8, 5);
      final notTaken = pendingIntake().recordNotTaken(at: recordedAt);

      expect(notTaken.status, IntakeStatus.notTaken);
      expect(notTaken.recordedAt, recordedAt);
    });

    test('rejects inconsistent status and recorded time', () {
      expect(
        () => MedicationIntake(
          id: 'intake-1',
          medicationId: 'medication-1',
          scheduledAt: scheduledAt,
          status: IntakeStatus.pending,
          recordedAt: scheduledAt,
        ),
        throwsArgumentError,
      );
      expect(
        () => MedicationIntake(
          id: 'intake-1',
          medicationId: 'medication-1',
          scheduledAt: scheduledAt,
          status: IntakeStatus.taken,
        ),
        throwsArgumentError,
      );
    });

    test('does not overwrite a completed intake', () {
      final taken = pendingIntake().recordTaken(at: scheduledAt);

      expect(() => taken.recordNotTaken(at: scheduledAt), throwsStateError);
    });
  });

  group('SnoozedReminder', () {
    test('creates a one-off reminder 15 minutes after the action', () {
      final createdAt = DateTime(2026, 10, 24, 8, 3);
      final intake = pendingIntake();
      final reminder = SnoozedReminder.after15Minutes(
        id: 'snooze-1',
        intake: intake,
        createdAt: createdAt,
      );

      expect(reminder.intakeId, intake.id);
      expect(reminder.createdAt, createdAt);
      expect(reminder.triggerAt, DateTime(2026, 10, 24, 8, 18));
      expect(intake.status, IntakeStatus.pending);
    });

    test('cannot snooze an intake that has already been recorded', () {
      final taken = pendingIntake().recordTaken(at: scheduledAt);

      expect(
        () => SnoozedReminder.after15Minutes(
          id: 'snooze-1',
          intake: taken,
          createdAt: scheduledAt,
        ),
        throwsStateError,
      );
    });

    test('rejects reminders that are not exactly 15 minutes later', () {
      expect(
        () => SnoozedReminder(
          id: 'snooze-1',
          intakeId: 'intake-1',
          createdAt: scheduledAt,
          triggerAt: scheduledAt.add(const Duration(minutes: 14)),
        ),
        throwsArgumentError,
      );
    });
  });
}
