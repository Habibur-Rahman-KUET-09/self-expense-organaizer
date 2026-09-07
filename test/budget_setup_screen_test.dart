import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/providers/database_providers.dart';
import 'package:expense_tracker/screens/budget_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildApp(AppDatabase db) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: BudgetSetupScreen()),
    );
  }

  testWidgets('shows empty state, then a newly added category with its budget', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(buildApp(db));
    await tester.pumpAndSettle();

    expect(find.text('No categories yet — tap + to add one.'), findsOneWidget);

    // Add a category via the FAB dialog.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Food');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Set budget'), findsOneWidget);

    // Set its budget.
    await tester.tap(find.text('Set budget'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '3000');
    await tester.enterText(fields.at(1), '5000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('৳3,000'), findsOneWidget);
    expect(find.textContaining('৳5,000'), findsOneWidget);
  });
}
