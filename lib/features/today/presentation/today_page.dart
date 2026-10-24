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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTodayIntakes();
  }

  Future<void> _loadTodayIntakes() async {
    setState(() {
      _isLoading = true;
    });

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
      final medication = await deps.medicationRepository.getById(intake.medicationId);
      if (medication != null) {
        displayItems.add(_IntakeDisplayItem(intake: intake, medication: medication));
      }
    }

    if (mounted) {
      setState(() {
        _items = displayItems;
        _isLoading = false;
      });
    }
  }

  Future<void> _recordStatus(MedicationIntake intake, bool taken) async {
    final deps = Dependencies.of(context);
    final now = DateTime.now();
    final updatedIntake = taken ? intake.recordTaken(at: now) : intake.recordNotTaken(at: now);

    await deps.historyRepository.save(updatedIntake);
    await _loadTodayIntakes();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _items ?? [];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Sua rotina de medicamentos',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Organize os horários e acompanhe suas tomadas de hoje.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        if (items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notifications_none,
                    color: Theme.of(context).colorScheme.primary,
                    size: 40,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sua rotina aparecerá aqui',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cadastre um medicamento na aba "Medicamentos" para gerar os horários de hoje.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          )
        else
          ...items.map((item) {
            final intake = item.intake;
            final med = item.medication;
            final timeStr = '${intake.scheduledAt.hour.toString().padLeft(2, '0')}:${intake.scheduledAt.minute.toString().padLeft(2, '0')}';

            final isPending = intake.status == IntakeStatus.pending;
            final isTaken = intake.status == IntakeStatus.taken;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      isPending
                          ? Icons.access_time
                          : isTaken
                              ? Icons.check_circle
                              : Icons.cancel,
                      color: isPending
                          ? Colors.orange
                          : isTaken
                              ? Colors.green
                              : Colors.red,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            med.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Horário: $timeStr · Dose: ${med.dose.amount} ${med.dose.unit.symbol}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    if (isPending) ...[
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _recordStatus(intake, true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _recordStatus(intake, false),
                      ),
                    ]
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _IntakeDisplayItem {
  _IntakeDisplayItem({required this.intake, required this.medication});

  final MedicationIntake intake;
  final Medication medication;
}
