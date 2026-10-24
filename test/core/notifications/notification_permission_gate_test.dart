import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medmais/core/notifications/medication_notification_service.dart';
import 'package:medmais/core/notifications/notification_permission_gate.dart';
import 'package:medmais/features/medications/domain/medication.dart';
import 'package:medmais/features/medications/domain/medication_intake.dart';

void main() {
  testWidgets('blocks app content until notification permission is granted', (
    tester,
  ) async {
    final service = _FakeNotificationService(
      permissionStatus: NotificationPermissionStatus.denied,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationPermissionGate(
          service: service,
          onReminderAction: (_) async {},
          child: const Text('Conteúdo do aplicativo'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('O Med+ não poderá ser usado'), findsOneWidget);
    expect(find.text('Conteúdo do aplicativo'), findsNothing);
    expect(find.text('Abrir configurações'), findsOneWidget);
    expect(service.initialized, isTrue);
  });

  testWidgets('shows app content once notifications and exact reminders work', (
    tester,
  ) async {
    final service = _FakeNotificationService(
      permissionStatus: NotificationPermissionStatus.granted,
      canScheduleExact: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationPermissionGate(
          service: service,
          onReminderAction: (_) async {},
          child: const Text('Conteúdo do aplicativo'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conteúdo do aplicativo'), findsOneWidget);
  });
}

class _FakeNotificationService implements MedicationNotificationService {
  _FakeNotificationService({
    required this.permissionStatus,
    this.canScheduleExact = false,
  });

  NotificationPermissionStatus permissionStatus;
  bool canScheduleExact;
  bool initialized = false;

  @override
  Future<bool> canScheduleExactReminders() async => canScheduleExact;

  @override
  Future<void> cancelIntakeReminder(String intakeId) async {}

  @override
  Future<void> cancelMedicationReminders(String medicationId) async {}

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async =>
      permissionStatus;

  @override
  Future<void> initialize({
    required Future<void> Function(ReminderAction action) onAction,
  }) async {
    initialized = true;
  }

  @override
  Future<bool> openNotificationSettings() async => true;

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      permissionStatus;

  @override
  Future<bool> requestExactReminderPermission() async => canScheduleExact;

  @override
  Future<void> scheduleIntakeReminder({
    required Medication medication,
    required MedicationIntake intake,
  }) async {}

  @override
  Future<void> scheduleSnoozedReminder({
    required Medication medication,
    required MedicationIntake intake,
    required SnoozedReminder snoozedReminder,
  }) async {}
}
