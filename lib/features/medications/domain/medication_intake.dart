enum IntakeStatus { pending, taken, notTaken }

class MedicationIntake {
  MedicationIntake({
    required String id,
    required String medicationId,
    required this.scheduledAt,
    this.status = IntakeStatus.pending,
    this.recordedAt,
  }) : id = id.trim(),
       medicationId = medicationId.trim() {
    if (this.id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (this.medicationId.isEmpty) {
      throw ArgumentError.value(
        medicationId,
        'medicationId',
        'Must not be empty.',
      );
    }
    if ((status == IntakeStatus.pending) != (recordedAt == null)) {
      throw ArgumentError(
        'Pending intakes must not have a recordedAt value; '
        'completed intakes must have one.',
      );
    }
  }

  final String id;
  final String medicationId;
  final DateTime scheduledAt;
  final IntakeStatus status;
  final DateTime? recordedAt;

  MedicationIntake recordTaken({required DateTime at}) =>
      _record(IntakeStatus.taken, at);

  MedicationIntake recordNotTaken({required DateTime at}) =>
      _record(IntakeStatus.notTaken, at);

  MedicationIntake _record(IntakeStatus result, DateTime at) {
    if (status != IntakeStatus.pending) {
      throw StateError('Only pending intakes can be recorded.');
    }

    return MedicationIntake(
      id: id,
      medicationId: medicationId,
      scheduledAt: scheduledAt,
      status: result,
      recordedAt: at,
    );
  }
}

class SnoozedReminder {
  SnoozedReminder({
    required String id,
    required String intakeId,
    required this.createdAt,
    required this.triggerAt,
  }) : id = id.trim(),
       intakeId = intakeId.trim() {
    if (this.id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (this.intakeId.isEmpty) {
      throw ArgumentError.value(intakeId, 'intakeId', 'Must not be empty.');
    }
    if (triggerAt.difference(createdAt) != const Duration(minutes: 15)) {
      throw ArgumentError.value(
        triggerAt,
        'triggerAt',
        'Must be exactly 15 minutes after creation.',
      );
    }
  }

  final String id;
  final String intakeId;
  final DateTime createdAt;
  final DateTime triggerAt;

  factory SnoozedReminder.after15Minutes({
    required String id,
    required MedicationIntake intake,
    required DateTime createdAt,
  }) {
    if (intake.status != IntakeStatus.pending) {
      throw StateError('Only pending intakes can be snoozed.');
    }

    return SnoozedReminder(
      id: id,
      intakeId: intake.id,
      createdAt: createdAt,
      triggerAt: createdAt.add(const Duration(minutes: 15)),
    );
  }
}
