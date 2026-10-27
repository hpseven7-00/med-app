
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'medication_notification_service.dart';

class NotificationPermissionGate extends StatefulWidget {
  final Widget child;
  final MedicationNotificationService service;
  final Future<void> Function(ReminderAction action) onReminderAction;

  const NotificationPermissionGate({
    super.key,
    required this.child,
    required this.service,
    required this.onReminderAction,
  });

  @override
  State<NotificationPermissionGate> createState() =>
      _NotificationPermissionGateState();
}

class _NotificationPermissionGateState
    extends State<NotificationPermissionGate> {
  NotificationPermissionStatus _permissionStatus =
      NotificationPermissionStatus.notDetermined;

  bool _canScheduleExactReminders = false;
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();

    // No Chrome, permite testar a interface sem notificações nativas.
    if (kIsWeb) {
      _isLoading = false;
      return;
    }

    _initialize();
  }

  Future<void> _initialize() async {
    if (kIsWeb) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.service.initialize(
        onAction: widget.onReminderAction,
      );

      await _refreshPermissions();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshPermissions() async {
    try {
      final status = await widget.service.getPermissionStatus();
      final canSchedule =
          await widget.service.canScheduleExactReminders();

      if (!mounted) return;

      setState(() {
        _permissionStatus = status;
        _canScheduleExactReminders = canSchedule;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestNotifications() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final status = await widget.service.requestPermission();

      if (!mounted) return;

      setState(() {
        _permissionStatus = status;
      });

      await _refreshPermissions();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestExactReminders() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await widget.service.requestExactReminderPermission();
      await _refreshPermissions();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _openNotificationSettings() async {
    try {
      final opened =
          await widget.service.openNotificationSettings();

      if (!opened) {
        await _refreshPermissions();
        return;
      }

      await _refreshPermissions();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // A implementação atual de notificações nativas não funciona na Web.
    if (kIsWeb) {
      return widget.child;
    }

    if (_permissionStatus == NotificationPermissionStatus.granted &&
        _canScheduleExactReminders &&
        !_isLoading &&
        _error == null) {
      return widget.child;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Med+'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ative os lembretes do Med+',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _permissionStatus ==
                            NotificationPermissionStatus.granted
                        ? 'O Med+ precisa de autorização para programar '
                            'lembretes em horários exatos. Permita esse acesso '
                            'nas configurações para continuar.'
                        : 'As notificações são necessárias para avisar você '
                            'nos horários dos medicamentos. O Med+ não poderá '
                            'ser usado enquanto elas não estiverem ativadas.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Não foi possível verificar as permissões: $_error',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_isLoading) ...[
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(),
                  ] else ...[
                    const SizedBox(height: 24),
                    if (_error != null)
                      FilledButton(
                        onPressed: _initialize,
                        child: const Text('Tentar novamente'),
                      )
                    else if (_permissionStatus ==
                        NotificationPermissionStatus.notDetermined)
                      FilledButton(
                        onPressed: _requestNotifications,
                        child: const Text('Ativar notificações'),
                      )
                    else if (_permissionStatus ==
                        NotificationPermissionStatus.denied)
                      FilledButton(
                        onPressed: _openNotificationSettings,
                        child: const Text('Abrir configurações'),
                      )
                    else if (!_canScheduleExactReminders)
                      FilledButton(
                        onPressed: _requestExactReminders,
                        child: const Text('Permitir horários exatos'),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
