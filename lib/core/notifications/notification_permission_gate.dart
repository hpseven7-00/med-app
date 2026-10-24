import 'package:flutter/material.dart';

import 'medication_notification_service.dart';

class NotificationPermissionGate extends StatefulWidget {
  const NotificationPermissionGate({
    required this.service,
    required this.onReminderAction,
    required this.child,
    super.key,
  });

  final MedicationNotificationService service;
  final Future<void> Function(ReminderAction action) onReminderAction;
  final Widget child;

  @override
  State<NotificationPermissionGate> createState() =>
      _NotificationPermissionGateState();
}

class _NotificationPermissionGateState extends State<NotificationPermissionGate>
    with WidgetsBindingObserver {
  NotificationPermissionStatus? _permissionStatus;
  bool _canScheduleExactReminders = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didUpdateWidget(covariant NotificationPermissionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _initialize();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initialize();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await widget.service.initialize(onAction: widget.onReminderAction);
      await _refreshPermissions();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _refreshPermissions() async {
    try {
      final permissionStatus = await widget.service.getPermissionStatus();
      final canScheduleExactReminders =
          permissionStatus == NotificationPermissionStatus.granted &&
          await widget.service.canScheduleExactReminders();
      if (!mounted) {
        return;
      }
      setState(() {
        _permissionStatus = permissionStatus;
        _canScheduleExactReminders = canScheduleExactReminders;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _requestNotifications() async {
    await _performPermissionAction(() async {
      await widget.service.requestPermission();
    });
  }

  Future<void> _openNotificationSettings() async {
    await _performPermissionAction(() async {
      final opened = await widget.service.openNotificationSettings();
      if (!opened) {
        throw StateError(
          'Não foi possível abrir as configurações de notificações.',
        );
      }
    });
  }

  Future<void> _requestExactReminders() async {
    await _performPermissionAction(() async {
      await widget.service.requestExactReminderPermission();
    });
  }

  Future<void> _performPermissionAction(Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await action();
      await _refreshPermissions();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
      _error = error.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionStatus == NotificationPermissionStatus.granted &&
        _canScheduleExactReminders &&
        !_isLoading &&
        _error == null) {
      return widget.child;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Med+')),
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
                    _permissionStatus == NotificationPermissionStatus.granted
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
                    else if (_permissionStatus !=
                        NotificationPermissionStatus.granted)
                      FilledButton(
                        onPressed:
                            _permissionStatus ==
                                NotificationPermissionStatus.denied
                            ? _openNotificationSettings
                            : _requestNotifications,
                        child: Text(
                          _permissionStatus ==
                                  NotificationPermissionStatus.denied
                              ? 'Abrir configurações'
                              : 'Ativar notificações',
                        ),
                      )
                    else
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
