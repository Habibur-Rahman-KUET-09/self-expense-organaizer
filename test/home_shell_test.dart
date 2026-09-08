import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/providers/database_providers.dart';
import 'package:expense_tracker/screens/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bottom nav switches between all four tabs, and quick links jump tabs', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(db.close);

    // Seed a budget so the Dashboard renders its normal (quick-links) view
    // instead of the "no budgets yet" empty state.
    final now = DateTime.now();
    final categoryId = await container
        .read(categoryRepositoryProvider)
        .add(name: 'Food');
    await container.read(budgetRepositoryProvider).upsert(
      BudgetsCompanion.insert(
        categoryId: categoryId,
        year: now.year,
        month: now.month,
        minCost: const Value(1000),
        maxCost: const Value(2000),
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();

    // Starts on Dashboard.
    expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Add Expense'), findsOneWidget);

    await tester.tap(find.text('Budgets'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Budget Setup'), findsOneWidget);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Reports'), findsOneWidget);

    // Back to Dashboard, then use its quick link to jump to Add Expense.
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    // Disambiguate from AddExpenseScreen's own (offstage but still built)
    // AppBar title, which carries the same text.
    await tester.tap(find.widgetWithText(InkWell, 'Add Expense'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Add Expense'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
