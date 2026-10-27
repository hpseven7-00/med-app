import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/dependencies/dependencies.dart';
import '../domain/medication.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

class AddMedicationPage extends StatefulWidget {
  const AddMedicationPage({super.key});

  @override
  State<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController(text: '1');

  DoseUnit _selectedUnit = DoseUnit.milligram;
  final Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7};
  final List<TimeOfDay> _selectedTimes = [
    const TimeOfDay(hour: 8, minute: 0),
  ];

  bool _isLoading = false;

  static const _dayLabels = [
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      helpText: 'Selecione o horário',
      cancelText: 'Cancelar',
      confirmText: 'Adicionar',
    );

    if (time == null || !mounted) return;

    final alreadyExists = _selectedTimes.any(
      (selected) =>
          selected.hour == time.hour &&
          selected.minute == time.minute,
    );

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esse horário já foi adicionado.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedTimes.add(time);
      _selectedTimes.sort((a, b) {
        final aMinutes = a.hour * 60 + a.minute;
        final bMinutes = b.hour * 60 + b.minute;
        return aMinutes.compareTo(bMinutes);
      });
    });
  }

  Future<void> _editTime(int index) async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTimes[index],
      helpText: 'Altere o horário',
      cancelText: 'Cancelar',
      confirmText: 'Salvar',
    );

    if (time == null || !mounted) return;

    final alreadyExists = _selectedTimes.asMap().entries.any(
      (entry) =>
          entry.key != index &&
          entry.value.hour == time.hour &&
          entry.value.minute == time.minute,
    );

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esse horário já foi adicionado.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedTimes[index] = time;
      _selectedTimes.sort((a, b) {
        final aMinutes = a.hour * 60 + a.minute;
        final bMinutes = b.hour * 60 + b.minute;
        return aMinutes.compareTo(bMinutes);
      });
    });
  }

  void _removeTime(int index) {
    if (_selectedTimes.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mantenha pelo menos um horário.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedTimes.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos um dia da semana.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final deps = Dependencies.of(context);
      final amount = double.parse(
        _amountController.text.trim().replaceAll(',', '.'),
      );

      final medication = Medication(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        dose: MedicationDose(
          amount: amount,
          unit: _selectedUnit,
        ),
        schedules: [
          MedicationSchedule(
            daysOfWeek: Set<int>.from(_selectedDays),
            times: _selectedTimes
                .map(
                  (time) => ScheduledTime(
                    hour: time.hour,
                    minute: time.minute,
                  ),
                )
                .toList(),
          ),
        ],
        createdAt: DateTime.now(),
      );

      await deps.medicationService.addMedication(medication);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar medicamento: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo medicamento'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Icon(
                LucideIcons.pill,
                size: 52,
                color: colors.primary,
              ),
              const SizedBox(height: 8),
              Text(
                'Vamos cadastrar seu medicamento',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Informe os dados e escolha quando deseja receber os lembretes.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),

              Text(
                '1. Dados do medicamento',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameController,
                enabled: !_isLoading,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Nome do medicamento',
                  hintText: 'Ex.: Paracetamol',
                  prefixIcon: Icon(Icons.medication_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome do medicamento.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountController,
                      enabled: !_isLoading,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        labelText: 'Dose',
                        hintText: 'Ex.: 1',
                        prefixIcon: Icon(Icons.scale_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final normalized =
                            value?.trim().replaceAll(',', '.');
                        final amount = double.tryParse(normalized ?? '');

                        if (amount == null ||
                            !amount.isFinite ||
                            amount <= 0) {
                          return 'Informe uma dose válida.';
                        }

                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<DoseUnit>(
                      initialValue: _selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unidade',
                        border: OutlineInputBorder(),
                      ),
                      items: DoseUnit.values.map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text(
                            unit.symbol,
                            style: const TextStyle(fontSize: 18),
                          ),
                        );
                      }).toList(),
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedUnit = value;
                                });
                              }
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              Text(
                '2. Dias da semana',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Selecione os dias em que deve tomar o medicamento.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (index) {
                  final day = index + 1;
                  final selected = _selectedDays.contains(day);

                  return FilterChip(
                    label: Text(
                      _dayLabels[index],
                      style: const TextStyle(fontSize: 16),
                    ),
                    selected: selected,
                    showCheckmark: true,
                    onSelected: _isLoading
                        ? null
                        : (value) {
                            setState(() {
                              if (value) {
                                _selectedDays.add(day);
                              } else {
                                _selectedDays.remove(day);
                              }
                            });
                          },
                  );
                }),
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          if (_selectedDays.length == 7) {
                            _selectedDays.clear();
                          } else {
                            _selectedDays.addAll(
                              [1, 2, 3, 4, 5, 6, 7],
                            );
                          }
                        });
                      },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  _selectedDays.length == 7
                      ? 'Desmarcar todos os dias'
                      : 'Selecionar todos os dias',
                ),
              ),
              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      '3. Horários dos lembretes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _isLoading ? null : _addTime,
                    tooltip: 'Adicionar horário',
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Adicione um horário para cada dose programada.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),

              ...List.generate(_selectedTimes.length, (index) {
                final time = _selectedTimes[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.alarm_outlined,
                      color: colors.primary,
                      size: 30,
                    ),
                    title: Text(
                      time.format(context),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text('Horário ${index + 1}'),
                    onTap: _isLoading ? null : () => _editTime(index),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Editar horário',
                          onPressed: _isLoading
                              ? null
                              : () => _editTime(index),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Remover horário',
                          onPressed: _isLoading
                              ? null
                              : () => _removeTime(index),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _isLoading ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isLoading
                      ? 'Salvando...'
                      : 'Salvar medicamento',
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
