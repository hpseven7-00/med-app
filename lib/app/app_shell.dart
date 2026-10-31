import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../features/history/presentation/history_page.dart';
import '../features/medications/presentation/medications_page.dart';
import '../features/today/presentation/today_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  final ValueNotifier<int> _refreshToday = ValueNotifier(0);

  late final List<Widget> _pages = [
    TodayPage(refreshSignal: _refreshToday),
    MedicationsPage(
      onMedicationAdded: () {
        _refreshToday.value++;
      },
    ),
    const HistoryPage(),
    const _DevelopmentPage(title: 'Perfil'),
  ];

  static const _titles = [
    'Início',
    'Meus medicamentos',
    'Histórico',
    'Perfil',
  ];

  @override
  void dispose() {
    _refreshToday.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 0
          ? null
          : AppBar(
              title: Text(_titles[_selectedIndex]),
              titleTextStyle: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Color(0xFF102D3A),
              ),
            ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.pill),
            selectedIcon: Icon(LucideIcons.pill),
            label: 'Medicamentos',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Histórico',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _DevelopmentPage extends StatelessWidget {
  const _DevelopmentPage({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.construction_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Em desenvolvimento',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}