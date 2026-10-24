import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/medications/domain/medication.dart';
import '../../features/medications/domain/medication_intake.dart';
import 'medication_notification_service.dart';

const _notificationChannelId = 'medication_reminders';
const _notificationChannelName = 'Lembretes de medicamentos';
const _notificationCategoryId = 'MEDICATION_REMINDER';
const _actionTaken = 'medication_taken';
const _actionNotTaken = 'medication_not_taken';
const _actionSnooze = 'medication_snooze_15';
const _pendingActionPrefix = 'pending_notification_action_';
const _permissionRequestedKey = 'notification_permission_requested';

@pragma('vm:entry-point')
void medicationNotificationBackgroundResponse(
  NotificationResponse response,
) async {
  final action = reminderActionFromResponse(response);
  if (action == null) {
    return;
  }

  final key = _pendingActionKey(action);
  await SharedPreferencesAsync().setString(
    key,
    jsonEncode({'intakeId': action.intakeId, 'type': action.type.name}),
  );
}

ReminderAction? reminderActionFromResponse(NotificationResponse response) {
  final type = switch (response.actionId) {
    _actionTaken => ReminderActionType.taken,
    _actionNotTaken => ReminderActionType.notTaken,
    _actionSnooze => ReminderActionType.snooze15Minutes,
    _ => null,
  };
  final payload = response.payload;
  if (type == null || payload == null || payload.isEmpty) {
    return null;
  }

  final decoded = jsonDecode(payload);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(
      'Reminder notification payload must be an object.',
    );
  }
  final intakeId = decoded['intakeId'];
  if (intakeId is! String || intakeId.isEmpty) {
    throw const FormatException(
      'Reminder notification payload has no intakeId.',
    );
  }

  return ReminderAction(intakeId: intakeId, type: type);
}

int notificationIdFor(String value) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(value)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  final positiveHash = hash & 0x7fffffff;
  return positiveHash == 0 ? 1 : positiveHash;
}

class FlutterLocalMedicationNotificationService
    implements MedicationNotificationService {
  FlutterLocalMedicationNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    SharedPreferencesAsync? preferences,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _preferences = preferences ?? SharedPreferencesAsync();

  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferencesAsync _preferences;
  Future<void> Function(ReminderAction action)? _onAction;
  bool _initialized = false;

  @override
  Future<void> initialize({
    required Future<void> Function(ReminderAction action) onAction,
  }) async {
    _onAction = onAction;
    if (!_initialized) {
      _ensureMobilePlatform();
      tz_data.initializeTimeZones();
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

      final initialized = await _plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
            notificationCategories: [
              DarwinNotificationCategory(
                _notificationCategoryId,
                actions: [
                  DarwinNotificationAction.plain(_actionTaken, 'Tomei'),
                  DarwinNotificationAction.plain(_actionNotTaken, 'Não tomei'),
                  DarwinNotificationAction.plain(_actionSnooze, 'Adiar 15 min'),
                ],
              ),
            ],
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
            notificationCategories: [
              DarwinNotificationCategory(
                _notificationCategoryId,
                actions: [
                  DarwinNotificationAction.plain(_actionTaken, 'Tomei'),
                  DarwinNotificationAction.plain(_actionNotTaken, 'Não tomei'),
                  DarwinNotificationAction.plain(_actionSnooze, 'Adiar 15 min'),
                ],
              ),
            ],
          ),
        ),
        onDidReceiveNotificationResponse: _handleForegroundResponse,
        onDidReceiveBackgroundNotificationResponse:
            medicationNotificationBackgroundResponse,
      );
      if (initialized != true) {
        throw StateError('Could not initialize the notification plugin.');
      }
      _initialized = true;
    }

    await _deliverQueuedActions();
  }

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async {
    _ensureMobilePlatform();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _androidPlugin;
      final enabled = await android.areNotificationsEnabled();
      if (enabled == true) {
        return NotificationPermissionStatus.granted;
      }
    } else {
      final settings = await _darwinPlugin.checkPermissions();
      if (settings != null &&
          settings.isAlertEnabled &&
          settings.isSoundEnabled) {
        return NotificationPermissionStatus.granted;
      }
    }

    final requestWasMade =
        await _preferences.getBool(_permissionRequestedKey) ?? false;
    return requestWasMade
        ? NotificationPermissionStatus.denied
        : NotificationPermissionStatus.notDetermined;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    _ensureInitialized();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _androidPlugin.requestNotificationsPermission();
    } else {
      await _darwinPlugin.requestPermissions(alert: true, sound: true);
    }
    await _preferences.setBool(_permissionRequestedKey, true);
    return getPermissionStatus();
  }

  @override
  Future<bool> canScheduleExactReminders() async {
    _ensureMobilePlatform();
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    return await _androidPlugin.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<bool> requestExactReminderPermission() async {
    _ensureInitialized();
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    await _androidPlugin.requestExactAlarmsPermission();
    return canScheduleExactReminders();
  }

  @override
  Future<bool> openNotificationSettings() async {
    _ensureInitialized();
    final result = defaultTargetPlatform == TargetPlatform.android
        ? await _androidPlugin.openAppNotificationSettings()
        : await _darwinPlugin.openAppNotificationSettings();
    return result ?? false;
  }

  @override
  Future<void> scheduleIntakeReminder({
    required Medication medication,
    required MedicationIntake intake,
  }) async {
    _ensureInitialized();
    await _ensureCanSchedule(medication, intake, requireFuture: true);
    await _plugin.zonedSchedule(
      id: notificationIdFor('intake:${intake.id}'),
      title: medication.name,
      body: _reminderBody(medication, intake.scheduledAt),
      scheduledDate: tz.TZDateTime.from(intake.scheduledAt, tz.local),
      payload: _payload(medication, intake),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      notificationDetails: _notificationDetails,
    );
  }

  @override
  Future<void> scheduleSnoozedReminder({
    required Medication medication,
    required MedicationIntake intake,
    required SnoozedReminder snoozedReminder,
  }) async {
    _ensureInitialized();
    await _ensureCanSchedule(medication, intake);
    if (snoozedReminder.intakeId != intake.id) {
      throw ArgumentError.value(
        snoozedReminder.intakeId,
        'snoozedReminder.intakeId',
        'Must match the intake ID.',
      );
    }
    if (!snoozedReminder.triggerAt.isAfter(DateTime.now())) {
      throw ArgumentError.value(
        snoozedReminder.triggerAt,
        'snoozedReminder.triggerAt',
        'Must be in the future.',
      );
    }

    await _plugin.zonedSchedule(
      id: notificationIdFor('snooze:${snoozedReminder.id}'),
      title: medication.name,
      body: '${_reminderBody(medication, snoozedReminder.triggerAt)} · Adiado',
      scheduledDate: tz.TZDateTime.from(snoozedReminder.triggerAt, tz.local),
      payload: _payload(medication, intake),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      notificationDetails: _notificationDetails,
    );
  }

  @override
  Future<void> cancelIntakeReminder(String intakeId) {
    _ensureInitialized();
    return _plugin.cancel(id: notificationIdFor('intake:$intakeId'));
  }

  @override
  Future<void> cancelMedicationReminders(String medicationId) async {
    _ensureInitialized();
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      final payload = notification.payload;
      if (payload == null || payload.isEmpty) {
        continue;
      }
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Reminder notification payload must be an object.',
        );
      }
      if (decoded['medicationId'] == medicationId) {
        await _plugin.cancel(id: notification.id);
      }
    }
  }

  AndroidFlutterLocalNotificationsPlugin get _androidPlugin =>
      _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >() ??
      (throw StateError('Android notification plugin is unavailable.'));

  IOSFlutterLocalNotificationsPlugin get _darwinPlugin =>
      _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >() ??
      (throw StateError('iOS notification plugin is unavailable.'));

  NotificationDetails get _notificationDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: 'Avisos nos horários programados dos medicamentos.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      actions: [
        AndroidNotificationAction(
          _actionTaken,
          'Tomei',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          _actionNotTaken,
          'Não tomei',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          _actionSnooze,
          'Adiar 15 min',
          showsUserInterface: false,
        ),
      ],
    ),
    iOS: DarwinNotificationDetails(
      categoryIdentifier: _notificationCategoryId,
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    ),
    macOS: DarwinNotificationDetails(
      categoryIdentifier: _notificationCategoryId,
      presentAlert: true,
      presentSound: true,
    ),
  );

  String _payload(Medication medication, MedicationIntake intake) =>
      jsonEncode({'medicationId': medication.id, 'intakeId': intake.id});

  String _reminderBody(Medication medication, DateTime scheduledAt) {
    final amount = medication.dose.amount;
    final formattedAmount = amount == amount.truncateToDouble()
        ? amount.toInt().toString()
        : amount.toString();
    final time = scheduledAt.toLocal();
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$formattedAmount ${medication.dose.unit.symbol} · $hour:$minute';
  }

  Future<void> _ensureCanSchedule(
    Medication medication,
    MedicationIntake intake, {
    bool requireFuture = false,
  }) async {
    if (!medication.isActive) {
      throw StateError('Cannot schedule reminders for an inactive medication.');
    }
    if (intake.medicationId != medication.id) {
      throw ArgumentError.value(
        intake.medicationId,
        'intake.medicationId',
        'Must match the medication ID.',
      );
    }
    if (intake.status != IntakeStatus.pending) {
      throw StateError('Only pending intakes can have reminders.');
    }
    if (requireFuture && !intake.scheduledAt.isAfter(DateTime.now())) {
      throw ArgumentError.value(
        intake.scheduledAt,
        'intake.scheduledAt',
        'Must be in the future.',
      );
    }
    if (await getPermissionStatus() != NotificationPermissionStatus.granted) {
      throw StateError('Notification permission has not been granted.');
    }
    if (!await canScheduleExactReminders()) {
      throw StateError('Exact reminder scheduling permission is not granted.');
    }
  }

  void _handleForegroundResponse(NotificationResponse response) {
    final action = reminderActionFromResponse(response);
    final handler = _onAction;
    if (action != null && handler != null) {
      unawaited(handler(action));
    }
  }

  Future<void> _deliverQueuedActions() async {
    final handler = _onAction!;
    final keys =
        (await _preferences.getKeys())
            .where((key) => key.startsWith(_pendingActionPrefix))
            .toList()
          ..sort();

    for (final key in keys) {
      final encoded = await _preferences.getString(key);
      if (encoded == null) {
        continue;
      }
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic> ||
          decoded['intakeId'] is! String ||
          decoded['type'] is! String) {
        throw const FormatException('Queued notification action is invalid.');
      }
      final type = ReminderActionType.values
          .where((value) => value.name == decoded['type'])
          .firstOrNull;
      if (type == null) {
        throw const FormatException(
          'Queued notification action type is invalid.',
        );
      }

      await handler(
        ReminderAction(intakeId: decoded['intakeId'] as String, type: type),
      );
      await _preferences.remove(key);
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('Notification service has not been initialized.');
    }
  }

  void _ensureMobilePlatform() {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      throw UnsupportedError(
        'Medication notifications are supported on Android and iOS.',
      );
    }
  }
}

String _pendingActionKey(ReminderAction action) {
  final encodedId = base64Url.encode(utf8.encode(action.intakeId));
  return '$_pendingActionPrefix$encodedId-${action.type.name}';
}
