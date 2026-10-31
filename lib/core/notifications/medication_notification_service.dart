import '../../features/medications/domain/medication.dart';
import '../../features/medications/domain/medication_intake.dart';

enum NotificationPermissionStatus { notDetermined, granted, denied }

enum ReminderActionType { taken, notTaken, snooze15Minutes }

class ReminderAction {
  const ReminderAction({required this.intakeId, required this.type});

  final String intakeId;
  final ReminderActionType type;
}

abstract interface class MedicationNotificationService {
  /// Initializes notification handling and delivers button actions without
  /// requiring the main application screen to open.
  Future<void> initialize({
    required Future<void> Function(ReminderAction action) onAction,
  });

  Future<NotificationPermissionStatus> getPermissionStatus();

  Future<NotificationPermissionStatus> requestPermission();

  /// Requests Android's special exact-alarm access when required.
  Future<bool> requestExactReminderPermission();

  Future<bool> canScheduleExactReminders();

  Future<bool> openNotificationSettings();

  /// Schedules the recurring occurrence represented by [intake].
  Future<void> scheduleIntakeReminder({
    required Medication medication,
    required MedicationIntake intake,
  });

  /// Schedules the one-off reminder; it must not change the recurring schedule.
  Future<void> scheduleSnoozedReminder({
    required Medication medication,
    required MedicationIntake intake,
    required SnoozedReminder snoozedReminder,
  });

  Future<void> cancelIntakeReminder(String intakeId);

  Future<void> cancelMedicationReminders(String medicationId);
}
