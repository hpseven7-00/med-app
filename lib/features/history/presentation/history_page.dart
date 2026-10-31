import 'package:flutter/material.dart';

import '../../../core/dependencies/dependencies.dart';
import '../../medications/domain/medication.dart';
import '../../medications/domain/medication_intake.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<_HistoryDisplayItem>? _items;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    final deps = Dependencies.of(context);
    final now = DateTime.now();
    // Historical items up to now
    final startOfTime = DateTime(2020, 1, 1);

    final intakes = await deps.historyRepository.getBetween(
      startInclusive: startOfTime,
      endExclusive: now,
    );

    // Filter only completed intakes
    final completedIntakes = intakes.where((i) => i.status != IntakeStatus.pending).toList();

    final displayItems = <_HistoryDisplayItem>[];
    for (final intake in completedIntakes) {
      final medication = await deps.medicationRepository.getById(intake.medicationId);
      if (medication != null) {
        displayItems.add(_HistoryDisplayItem(intake: intake, medication: medication));
      }
    }

    if (mounted) {
      setState(() {
        _items = displayItems.reversed.toList(); // most recent first
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _items ?? [];

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history,
                color: Theme.of(context).colorScheme.primary,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                'Seu histórico aparecerá aqui',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'As tomadas registradas ficarão disponíveis nesta tela.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final intake = item.intake;
        final med = item.medication;
        final isTaken = intake.status == IntakeStatus.taken;

        final dateStr = '${intake.scheduledAt.day.toString().padLeft(2, '0')}/${intake.scheduledAt.month.toString().padLeft(2, '0')} ${intake.scheduledAt.hour.toString().padLeft(2, '0')}:${intake.scheduledAt.minute.toString().padLeft(2, '0')}';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              isTaken ? Icons.check_circle : Icons.cancel,
              color: isTaken ? Colors.green : Colors.red,
            ),
            title: Text(med.name),
            subtitle: Text('Agendado para: $dateStr'),
            trailing: Text(
              isTaken ? 'Tomei' : 'Não tomei',
              style: TextStyle(
                color: isTaken ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HistoryDisplayItem {
  _HistoryDisplayItem({required this.intake, required this.medication});

  final MedicationIntake intake;
  final Medication medication;
}
