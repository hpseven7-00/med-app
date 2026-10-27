import 'package:flutter/material.dart';

import '../../../core/dependencies/dependencies.dart';
import '../../medications/domain/medication.dart';
import '../../medications/domain/medication_intake.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  List<_IntakeDisplayItem>? _items;
  bool _isLoading = true;

  static const _weekdays = [
    'Seg.',
    'Ter.',
    'Qua.',
    'Qui.',
    'Sex.',
    'Sáb.',
    'Dom.',
  ];

  static const _months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  static const _medicationColors = [
    Color(0xFF16804A),
    Color(0xFF1678A8),
    Color(0xFFC62836),
    Color(0xFFE58A19),
  ];

  @override
  void initState() {
    super.initState();
    _loadTodayIntakes();
  }

  String _formatDate(DateTime date) {
    final weekday = _weekdays[date.weekday - 1];
    final month = _months[date.month - 1];

    return '$weekday ${date.day} de $month';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Future<void> _loadTodayIntakes() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final deps = Dependencies.of(context);
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final intakes = await deps.historyRepository.getBetween(
        startInclusive: startOfDay,
        endExclusive: endOfDay,
      );

      final displayItems = <_IntakeDisplayItem>[];

      for (final intake in intakes) {
        final medication = await deps.medicationRepository
            .getById(intake.medicationId);

        if (medication != null) {
          displayItems.add(
            _IntakeDisplayItem(
              intake: intake,
              medication: medication,
            ),
          );
        }
      }

      displayItems.sort(
        (a, b) => a.intake.scheduledAt.compareTo(b.intake.scheduledAt),
      );

      if (!mounted) return;

      setState(() {
        _items = displayItems;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível carregar as doses: $e'),
        ),
      );
    }
  }

  Future<void> _recordStatus(
    MedicationIntake intake,
    bool taken,
  ) async {
    try {
      final deps = Dependencies.of(context);
      final now = DateTime.now();

      final updatedIntake = taken
          ? intake.recordTaken(at: now)
          : intake.recordNotTaken(at: now);

      await deps.historyRepository.save(updatedIntake);

      await _loadTodayIntakes();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível atualizar a dose: $e'),
        ),
      );
    }
  }

  Color _statusColor(MedicationIntake intake) {
    switch (intake.status) {
      case IntakeStatus.pending:
        return const Color(0xFFB3261E);
      case IntakeStatus.taken:
        return const Color(0xFF176B43);
      case IntakeStatus.notTaken:
        return const Color(0xFFB3261E);
    }
  }

  String _statusLabel(MedicationIntake intake) {
    switch (intake.status) {
      case IntakeStatus.pending:
        return 'Pendente';
      case IntakeStatus.taken:
        return 'Confirmado';
      case IntakeStatus.notTaken:
        return 'Não tomado';
    }
  }

  IconData _statusIcon(MedicationIntake intake) {
    switch (intake.status) {
      case IntakeStatus.pending:
        return Icons.schedule_outlined;
      case IntakeStatus.taken:
        return Icons.check_circle_outline;
      case IntakeStatus.notTaken:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final items = _items ?? [];
    final today = DateTime.now();

    return RefreshIndicator(
      onRefresh: _loadTodayIntakes,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            'Hoje',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: 38,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF102D3A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatDate(today),
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 22,
              color: const Color(0xFF183744),
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.medication_outlined,
                    size: 48,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma dose para hoje',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cadastre seus medicamentos para acompanhar '
                    'os horários nesta tela.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final intake = item.intake;
                  final medication = item.medication;
                  final color = _medicationColors[
                      index % _medicationColors.length];
                  final isPending =
                      intake.status == IntakeStatus.pending;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.13),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.medication,
                                color: color,
                                size: 38,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatTime(intake.scheduledAt),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontSize: 25,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF102D3A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${medication.name} '
                                    '${medication.dose.amount} '
                                    '${medication.dose.unit.symbol}',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontSize: 19,
                                      color: const Color(0xFF102D3A),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(
                                        _statusIcon(intake),
                                        color: _statusColor(intake),
                                        size: 22,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _statusLabel(intake),
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            color: _statusColor(intake),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isPending) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () =>
                                              _recordStatus(intake, true),
                                          icon: const Icon(
                                            Icons.check_circle_outline,
                                            size: 18,
                                          ),
                                          label: const Text('Confirmar'),
                                        ),
                                        TextButton.icon(
                                          onPressed: () =>
                                              _recordStatus(intake, false),
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                          label: const Text('Não tomei'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (index < items.length - 1)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFDCE5E7),
                        ),
                    ],
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _IntakeDisplayItem {
  const _IntakeDisplayItem({
    required this.intake,
    required this.medication,
  });

  final MedicationIntake intake;
  final Medication medication;
}
