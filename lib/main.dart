
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app/app_shell.dart';
import 'app/med_mais_theme.dart';
import 'app/splash_screen.dart';
import 'core/database/med_mais_database.dart';
import 'core/dependencies/dependencies.dart';
import 'core/notifications/flutter_local_medication_notification_service.dart';
import 'core/notifications/medication_notification_service.dart';
import 'core/notifications/notification_permission_gate.dart';
import 'features/history/data/sqlite_intake_history_repository.dart';
import 'features/medications/application/medication_service.dart';
import 'features/medications/data/sqlite_medication_repository.dart';
import 'features/medications/domain/medication_intake.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MedMaisBootstrap());
}

class MedMaisBootstrap extends StatefulWidget {
  const MedMaisBootstrap({super.key});

  @override
  State<MedMaisBootstrap> createState() => _MedMaisBootstrapState();
}

class _MedMaisBootstrapState extends State<MedMaisBootstrap> {
  Widget? _app;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Inicializa a fábrica do SQLite para execução no navegador.
      if (kIsWeb) {
        databaseFactory = databaseFactoryFfiWeb;
      }

      // Abre o banco de dados.
      final database = await MedMaisDatabase.open();

      // Inicializa os repositórios.
      final medicationRepository =
          SqliteMedicationRepository(database);

      final historyRepository =
          SqliteIntakeHistoryRepository(database);

      // Inicializa o serviço de notificações.
      final notificationService =
          FlutterLocalMedicationNotificationService();

      // Inicializa o serviço de medicamentos.
      final medicationService = MedicationService(
        medicationRepository: medicationRepository,
        historyRepository: historyRepository,
        notificationService: notificationService,
      );

      // Sincroniza os horários dos medicamentos.
      await medicationService.synchronizeIntakes();

      // Monta o aplicativo após a inicialização.
      final app = Dependencies(
        medicationRepository: medicationRepository,
        historyRepository: historyRepository,
        notificationService: notificationService,
        medicationService: medicationService,
        child: const MedMaisApp(),
      );

      if (!mounted) return;

      setState(() {
        _app = app;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Não foi possível iniciar o Med+.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Detalhes: $_error',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                      });
                      _initializeApp();
                    },
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return _app ?? const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
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
          final intake = await deps.historyRepository.getById(
            action.intakeId,
          );

          if (intake == null ||
              intake.status != IntakeStatus.pending) {
            return;
          }

          final medication = await deps.medicationRepository.getById(
            intake.medicationId,
          );

          if (medication == null) {
            return;
          }

          final now = DateTime.now();

          switch (action.type) {
            case ReminderActionType.taken:
              await deps.historyRepository.save(
                intake.recordTaken(at: now),
              );
              break;

            case ReminderActionType.notTaken:
              await deps.historyRepository.save(
                intake.recordNotTaken(at: now),
              );
              break;

            case ReminderActionType.snooze15Minutes:
              final snoozed = SnoozedReminder.after15Minutes(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
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
