import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medmais/core/notifications/flutter_local_medication_notification_service.dart';
import 'package:medmais/core/notifications/medication_notification_service.dart';

void main() {
  group('reminderActionFromResponse', () {
    test('parses a supported action and intake ID', () {
      final action = reminderActionFromResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'medication_snooze_15',
          payload: '{"medicationId":"med-1","intakeId":"intake-1"}',
        ),
      );

      expect(action, isNotNull);
      expect(action!.intakeId, 'intake-1');
      expect(action.type, ReminderActionType.snooze15Minutes);
    });

    test('ignores unknown actions and notification body taps', () {
      expect(
        reminderActionFromResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'unknown',
            payload: '{"intakeId":"intake-1"}',
          ),
        ),
        isNull,
      );
      expect(
        reminderActionFromResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: '{"intakeId":"intake-1"}',
          ),
        ),
        isNull,
      );
    });

    test('rejects malformed payloads for known actions', () {
      expect(
        () => reminderActionFromResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'medication_taken',
            payload: '{"intakeId":3}',
          ),
        ),
        throwsFormatException,
      );
    });
  });

  test('notification IDs are deterministic positive integers', () {
    final first = notificationIdFor('intake:intake-1');

    expect(first, greaterThan(0));
    expect(first, lessThanOrEqualTo(0x7fffffff));
    expect(notificationIdFor('intake:intake-1'), first);
    expect(notificationIdFor('intake:intake-2'), isNot(first));
  });
}
