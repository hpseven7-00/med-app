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

  Future<void> _generateAndScheduleIntakes(Medication medication, {required int daysToGenerate}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDate = today.add(Duration(days: daysToGenerate));

    const uuid = Uuid();

    for (var date = today; date.isBefore(endDate); date = date.add(const Duration(days: 1))) {
      for (final schedule in medication.schedules) {
        if (schedule.daysOfWeek.contains(date.weekday)) {
          for (final time in schedule.times) {
            final scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);

            // Somente criar e agendar para horários no futuro (ou no momento)
            if (!scheduledAt.isBefore(now)) {
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
              } catch (e) {
                // Ignore scheduling errors if permission is denied, for example.
                // The gate will ask for permissions and we can reschedule later if needed.
              }
            }
          }
        }
      }
    }
  }
}
