import 'package:flutter/material.dart';

import 'app/app_shell.dart';
import 'app/med_mais_theme.dart';

void main() {
  runApp(const MedMaisApp());
}

class MedMaisApp extends StatelessWidget {
  const MedMaisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Med+',
      theme: MedMaisTheme.light,
      home: const AppShell(),
    );
  }
}
