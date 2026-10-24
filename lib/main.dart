import 'package:flutter/material.dart';

import 'app/app_shell.dart';
import 'app/med_mais_theme.dart';
import 'core/database/med_mais_database.dart';
import 'core/dependencies/dependencies.dart';
import 'core/notifications/flutter_local_medication_notification_service.dart';
import 'core/notifications/medication_notification_service.dart';
import 'core/notifications/notification_permission_gate.dart';
import 'features/history/data/sqlite_intake_history_repository.dart';
import 'features/medications/application/medication_service.dart';
import 'features/medications/data/sqlite_medication_repository.dart';
import 'features/medications/domain/medication_intake.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = await MedMaisDatabase.open();
  final medicationRepository = SqliteMedicationRepository(database);
  final historyRepository = SqliteIntakeHistoryRepository(database);
  final notificationService = FlutterLocalMedicationNotificationService();
  final medicationService = MedicationService(
    medicationRepository: medicationRepository,
    historyRepository: historyRepository,
    notificationService: notificationService,
  );

  runApp(
    Dependencies(
      medicationRepository: medicationRepository,
      historyRepository: historyRepository,
      notificationService: notificationService,
      medicationService: medicationService,
      child: const MedMaisApp(),
    ),
  );
}

class MedMaisApp extends StatelessWidget {
  const MedMaisApp({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = Dependencies.of(context);

    return MaterialApp(
      title: 'Med+',
      theme: MedMaisTheme.light,
      home: NotificationPermissionGate(
        service: deps.notificationService,
        onReminderAction: (action) async {
          final intake = await deps.historyRepository.getById(action.intakeId);
          if (intake == null || intake.status != IntakeStatus.pending) {
            return;
          }

          final medication = await deps.medicationRepository.getById(intake.medicationId);
          if (medication == null) {
            return;
          }

          final now = DateTime.now();
          switch (action.type) {
            case ReminderActionType.taken:
              await deps.historyRepository.save(intake.recordTaken(at: now));
              break;
            case ReminderActionType.notTaken:
              await deps.historyRepository.save(intake.recordNotTaken(at: now));
              break;
            case ReminderActionType.snooze15Minutes:
              final snoozed = SnoozedReminder.after15Minutes(
                id: DateTime.now().millisecondsSinceEpoch.toString(), // Simplified ID for snooze
                intake: intake,
                createdAt: now,
              );
              await deps.notificationService.scheduleSnoozedReminder(
                medication: medication,
                intake: intake,
                snoozedReminder: snoozed,
              );
              break;
          }
        },
        child: const AppShell(),
      ),
    );
  }
}