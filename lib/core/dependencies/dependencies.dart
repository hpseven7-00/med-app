import 'package:flutter/widgets.dart';

import '../../features/history/domain/intake_history_repository.dart';
import '../../features/medications/data/medication_repository.dart';
import '../../features/medications/application/medication_service.dart';
import '../notifications/medication_notification_service.dart';

class Dependencies extends InheritedWidget {
  const Dependencies({
    required super.child,
    required this.medicationRepository,
    required this.historyRepository,
    required this.notificationService,
    required this.medicationService,
    super.key,
  });

  final MedicationRepository medicationRepository;
  final IntakeHistoryRepository historyRepository;
  final MedicationNotificationService notificationService;
  final MedicationService medicationService;

  static Dependencies of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<Dependencies>();
    assert(result != null, 'No Dependencies found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(Dependencies oldWidget) => false;
}
