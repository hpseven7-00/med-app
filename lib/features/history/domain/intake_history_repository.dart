import '../../medications/domain/medication_intake.dart';

abstract interface class IntakeHistoryRepository {
  /// Fetches a specific intake by its ID. Returns null if not found.
  Future<MedicationIntake?> getById(String id);

  /// Stores a pending intake or updates its explicit user-recorded status.
  Future<void> save(MedicationIntake intake);

  /// Returns intakes in [startInclusive, endExclusive), including pending ones.
  Future<List<MedicationIntake>> getBetween({
    required DateTime startInclusive,
    required DateTime endExclusive,
  });
}
