import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/dependencies/dependencies.dart';
import '../domain/medication.dart';
import 'add_medication_page.dart';

enum _MedicationFilter {
  all,
  inUse,
  comingSoon,
}

class MedicationsPage extends StatefulWidget {
  const MedicationsPage({super.key});

  @override
  State<MedicationsPage> createState() => _MedicationsPageState();
}

class _MedicationsPageState extends State<MedicationsPage> {
  List<Medication> _medications = [];
  bool _isLoading = true;

  _MedicationFilter _selectedFilter = _MedicationFilter.all;

  static const _medicationColors = [
    Color(0xFF187653),
    Color(0xFF1678A8),
    Color(0xFFE58A19),
  ];

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final deps = Dependencies.of(context);
      final medications = await deps.medicationRepository.getAll();

      medications.sort(
        (a, b) => a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            ),
      );

      if (!mounted) return;

      setState(() {
        _medications = medications;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível carregar os medicamentos: $e',
          ),
        ),
      );
    }
  }

  DateTime? _nextScheduledTime(Medication medication) {
    final now = DateTime.now();

    for (var dayOffset = 0; dayOffset < 8; dayOffset++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: dayOffset));

      for (final schedule in medication.schedules) {
        if (!schedule.daysOfWeek.contains(date.weekday)) {
          continue;
        }

        final times = [...schedule.times]
          ..sort((a, b) {
            final aMinutes = a.hour * 60 + a.minute;
            final bMinutes = b.hour * 60 + b.minute;

            return aMinutes.compareTo(bMinutes);
          });

        for (final time in times) {
          final scheduledAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );

          if (!scheduledAt.isBefore(now)) {
            return scheduledAt;
          }
        }
      }
    }

    return null;
  }

  List<Medication> get _filteredMedications {
    switch (_selectedFilter) {
      case _MedicationFilter.all:
        return _medications;

      case _MedicationFilter.inUse:
        // Considera em uso os medicamentos que possuem horários
        // e dias da semana configurados.
        return _medications
            .where(
              (medication) => medication.schedules.any(
                (schedule) =>
                    schedule.daysOfWeek.isNotEmpty &&
                    schedule.times.isNotEmpty,
              ),
            )
            .toList();

      case _MedicationFilter.comingSoon:
        final now = DateTime.now();

        return _medications.where((medication) {
          final nextTime = _nextScheduledTime(medication);

          return nextTime != null &&
              nextTime.isAfter(now) &&
              nextTime.difference(now) <= const Duration(hours: 24);
        }).toList();
    }
  }

  String _formatTime(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  String _scheduleDescription(Medication medication) {
    final nextTime = _nextScheduledTime(medication);

    if (nextTime == null) {
      return '${medication.dose.amount} '
          '${medication.dose.unit.symbol} · Sem horário próximo';
    }

    return '${medication.dose.amount} '
        '${medication.dose.unit.symbol} · '
        '${_formatTime(nextTime.hour, nextTime.minute)}';
  }

  Future<void> _openAddMedication() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AddMedicationPage(),
      ),
    );

    if (result == true) {
      await _loadMedications();
    }
  }

 Widget _buildFilter(
    String label,
    _MedicationFilter filter,
  ) {
    final selected = _selectedFilter == filter;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,

      labelStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: selected
            ? Colors.white
            : const Color(0xFF183744),
      ),

      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
      ),

      selectedColor: const Color(0xFF105968),
      backgroundColor: const Color(0xFFE1EBED),

      shape: const StadiumBorder(),
      side: BorderSide.none,

      onSelected: (_) {
        setState(() {
          _selectedFilter = filter;
        });
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    final message = switch (_selectedFilter) {
      _MedicationFilter.all =>
        'Cadastre seu primeiro medicamento usando o botão +.',
      _MedicationFilter.inUse =>
        'Nenhum medicamento com horários configurados.',
      _MedicationFilter.comingSoon =>
        'Nenhuma dose prevista para as próximas 24 horas.',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 48,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.pill,
            size: 52,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum medicamento encontrado',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF102D3A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF183744),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationList(
    ThemeData theme,
    List<Medication> medications,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
          width: 1,
        ),
      ),
      child: Column(
        children: List.generate(medications.length, (index) {
          final medication = medications[index];

          final color = _medicationColors[
              index % _medicationColors.length];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.pill,
                        size: 38,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${medication.name} '
                            '${medication.dose.amount} '
                            '${medication.dose.unit.symbol}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF102D3A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _scheduleDescription(medication),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF183744),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (index < medications.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFDCE5E7),
                ),
            ],
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medications = _filteredMedications;

    return Scaffold(
      backgroundColor: const Color(0xFFE3F5EF),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _openAddMedication,
        tooltip: 'Adicionar medicamento',
        backgroundColor: const Color(0xFF105968),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE3F5EF),
              Color(0xFFDDF1F5),
              Color(0xFFEAF7F5),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Elementos abstratos suaves no fundo.
            Positioned(
              top: 35,
              right: -75,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.24),
                ),
              ),
            ),
            Positioned(
              top: 260,
              left: -115,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFB8E5DF)
                      .withValues(alpha: 0.22),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              right: -95,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFB9E4F0)
                      .withValues(alpha: 0.20),
                ),
              ),
            ),

            // Conteúdo sobre o gradiente.
            RefreshIndicator(
              onRefresh: _loadMedications,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 88),
                children: [
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilter(
                          'Todos',
                          _MedicationFilter.all,
                        ),
                        _buildFilter(
                          'Em uso',
                          _MedicationFilter.inUse,
                        ),
                        _buildFilter(
                          'Em breve',
                          _MedicationFilter.comingSoon,
                        ),
                      ],
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
                  else if (medications.isEmpty)
                    _buildEmptyState()
                  else
                    _buildMedicationList(theme, medications),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
