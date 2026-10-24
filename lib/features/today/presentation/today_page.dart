import 'package:flutter/material.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Sua rotina de medicamentos', style: textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Organize os horários e acompanhe suas tomadas.',
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notifications_none,
                  color: colorScheme.primary,
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text('Sua rotina aparecerá aqui', style: textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Cadastre um medicamento para começar a organizar '
                  'seus horários.',
                  style: textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
