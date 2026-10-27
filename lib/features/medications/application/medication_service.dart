
import 'package:uuid/uuid.dart';

import '../../history/domain/intake_history_repository.dart';
import '../../../core/notifications/medication_notification_service.dart';
import '../domain/medication.dart';
import '../domain/medication_intake.dart';
import '../data/medication_repository.dart';

class MedicationService {
  const MedicationService({
    required this.medicationRepository,
    required this.historyRepository,
    required this.notificationService,
  });

  final MedicationRepository medicationRepository;
  final IntakeHistoryRepository historyRepository;
  final MedicationNotificationService notificationService;

  Future<void> addMedication(Medication medication) async {
    await medicationRepository.save(medication);
    await _generateAndScheduleIntakes(medication, daysToGenerate: 30);
  }

  /// Gera doses para medicamentos já cadastrados sem duplicar
  /// registros que possuam o mesmo medicamento e horário agendado.
  Future<void> synchronizeIntakes() async {
    final medications = await medicationRepository.getAll();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endDate = startOfDay.add(const Duration(days: 30));

    final existingIntakes = await historyRepository.getBetween(
      startInclusive: startOfDay,
      endExclusive: endDate,
    );

    final existingKeys = existingIntakes
        .map((intake) => _intakeKey(intake.medicationId, intake.scheduledAt))
        .toSet();

    for (final medication in medications) {
      await _generateAndScheduleIntakes(
        medication,
        daysToGenerate: 30,
        existingKeys: existingKeys,
      );
    }
  }

  String _intakeKey(String medicationId, DateTime scheduledAt) {
    final date = scheduledAt.toLocal();
    final normalizedDate = DateTime(
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
    );

    return '$medicationId|${normalizedDate.toIso8601String()}';
  }

  Future<void> _generateAndScheduleIntakes(
    Medication medication, {
    required int daysToGenerate,
    Set<String>? existingKeys,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDate = today.add(Duration(days: daysToGenerate));

    const uuid = Uuid();
    final knownKeys = existingKeys ?? <String>{};

    for (
      var date = today;
      date.isBefore(endDate);
      date = date.add(const Duration(days: 1))
    ) {
      for (final schedule in medication.schedules) {
        if (!schedule.daysOfWeek.contains(date.weekday)) {
          continue;
        }

        for (final time in schedule.times) {
          final scheduledAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );

          if (scheduledAt.isBefore(now)) {
            continue;
          }

          final key = _intakeKey(medication.id, scheduledAt);

          if (!knownKeys.add(key)) {
            continue;
          }

          final intake = MedicationIntake(
            id: uuid.v4(),
            medicationId: medication.id,
            scheduledAt: scheduledAt,
          );

          await historyRepository.save(intake);

          try {
            await notificationService.scheduleIntakeReminder(
              medication: medication,
              intake: intake,
            );
          } catch (_) {
            // A falha na notificação não deve impedir a geração das doses.
          }
        }
      }
    }
  }
}
