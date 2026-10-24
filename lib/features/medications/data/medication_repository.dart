import '../domain/medication.dart';

abstract interface class MedicationRepository {
  Future<Medication?> getById(String id);

  Future<List<Medication>> getAll({bool includeInactive = false});

  /// Inserts a medication or updates the existing record with the same ID.
  Future<void> save(Medication medication);
}
