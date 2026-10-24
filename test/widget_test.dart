// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:medmais/main.dart';

void main() {
  testWidgets('shows the Med+ home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MedMaisApp());

    expect(find.text('Med+'), findsOneWidget);
    expect(find.text('Sua rotina de medicamentos'), findsOneWidget);
    expect(find.text('Sua rotina aparecerá aqui'), findsOneWidget);
  });

  testWidgets('navigates between today, medications, and history', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MedMaisApp());

    await tester.tap(find.text('Medicamentos'));
    await tester.pumpAndSettle();
    expect(find.text('Meus medicamentos'), findsOneWidget);
    expect(find.text('Nenhum medicamento cadastrado'), findsOneWidget);

    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Seu histórico aparecerá aqui'), findsOneWidget);

    await tester.tap(find.text('Hoje'));
    await tester.pumpAndSettle();
    expect(find.text('Sua rotina aparecerá aqui'), findsOneWidget);
  });
}
