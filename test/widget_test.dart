// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medmais/main.dart';
import 'package:medmais/core/notifications/medication_notification_service.dart';
import 'package:medmais/features/medications/domain/medication.dart';
import 'package:medmais/features/medications/domain/medication_intake.dart';

import 'package:medmais/core/dependencies/dependencies.dart';
import 'package:medmais/features/history/domain/intake_history_repository.dart';
import 'package:medmais/features/medications/data/medication_repository.dart';
import 'package:medmais/features/medications/application/medication_service.dart';

class _FakeNotificationService implements MedicationNotificationService {
  @override
  Future<void> initialize({required Future<void> Function(ReminderAction action) onAction}) async {}

  @override
  Future<bool> canScheduleExactReminders() async => true;

  @override
  Future<void> cancelIntakeReminder(String intakeId) async {}

  @override
  Future<void> cancelMedicationReminders(String medicationId) async {}

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async => NotificationPermissionStatus.granted;

  @override
  Future<bool> openNotificationSettings() async => true;

  @override
  Future<bool> requestExactReminderPermission() async => true;

  @override
  Future<NotificationPermissionStatus> requestPermission() async => NotificationPermissionStatus.granted;

  @override
  Future<void> scheduleIntakeReminder({required Medication medication, required MedicationIntake intake}) async {}

  @override
  Future<void> scheduleSnoozedReminder({required Medication medication, required MedicationIntake intake, required SnoozedReminder snoozedReminder}) async {}
}

class _FakeMedicationRepository implements MedicationRepository {
  @override
  Future<List<Medication>> getAll({bool includeInactive = false}) async => [];

  @override
  Future<Medication?> getById(String id) async => null;

  @override
  Future<void> save(Medication medication) async {}
}

class _FakeHistoryRepository implements IntakeHistoryRepository {
  @override
  Future<MedicationIntake?> getById(String id) async => null;

  @override
  Future<List<MedicationIntake>> getBetween({required DateTime startInclusive, required DateTime endExclusive}) async => [];

  @override
  Future<void> save(MedicationIntake intake) async {}
}

class _FakeMedicationService implements MedicationService {
  @override
  IntakeHistoryRepository get historyRepository => _FakeHistoryRepository();

  @override
  MedicationRepository get medicationRepository => _FakeMedicationRepository();

  @override
  MedicationNotificationService get notificationService => _FakeNotificationService();

  @override
  Future<void> addMedication(Medication medication) async {}
}

Widget _buildTestApp() {
  return Dependencies(
    medicationRepository: _FakeMedicationRepository(),
    historyRepository: _FakeHistoryRepository(),
    notificationService: _FakeNotificationService(),
    medicationService: _FakeMedicationService(),
    child: const MedMaisApp(),
  );
}

void main() {
  testWidgets('shows the Med+ home screen', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle(); // Aguarda a inicialização do NotificationPermissionGate

    expect(find.text('Med+'), findsWidgets); // Modified to findsWidgets since there might be multiple texts (AppBar and nav label)
    expect(find.text('Sua rotina de medicamentos'), findsOneWidget);
    expect(find.text('Sua rotina aparecerá aqui'), findsOneWidget);
  });

  testWidgets('navigates between today, medications, and history', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle(); // Aguarda a inicialização do NotificationPermissionGate

    await tester.tap(find.text('Medicamentos').last); // Tapping the navigation label
    await tester.pumpAndSettle();
    expect(find.text('Meus medicamentos'), findsWidgets);
    expect(find.text('Nenhum medicamento cadastrado'), findsOneWidget);


    await tester.tap(find.text('Histórico').last);
    await tester.pumpAndSettle();
    expect(find.text('Seu histórico aparecerá aqui'), findsOneWidget);

    await tester.tap(find.text('Hoje').last);
    await tester.pumpAndSettle();
    expect(find.text('Sua rotina aparecerá aqui'), findsOneWidget);
  });
}
