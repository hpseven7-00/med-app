import '../../medications/domain/medication_intake.dart';

abstract interface class IntakeHistoryRepository {
  /// Stores a pending intake or updates its explicit user-recorded status.
  Future<void> save(MedicationIntake intake);

  /// Returns intakes in [startInclusive, endExclusive), including pending ones.
  Future<List<MedicationIntake>> getBetween({
    required DateTime startInclusive,
    required DateTime endExclusive,
  });
}
