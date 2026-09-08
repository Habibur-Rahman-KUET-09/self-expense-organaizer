import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/providers/database_providers.dart';
import 'package:expense_tracker/screens/budget_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows empty state, then a newly added category with its budget', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    // Own the ProviderContainer ourselves (via UncontrolledProviderScope)
    // instead of letting ProviderScope create/dispose one implicitly. That
    // way we can dispose it *inside* the test body — while we can still
    // pump — rather than relying on flutter_test's automatic post-test
    // teardown, which disposes the widget tree after the test body
    // returns and gives drift's query streams no chance to run their
    // zero-duration cancellation Timer before the "no pending timers"
    // invariant check.
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(db.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BudgetSetupScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No categories yet — tap + to add one.'), findsOneWidget);

    // Export action is present (NFR-6). Only open the menu — actually
    // selecting an item would hit share_plus's platform channel, which
    // isn't mocked in this test environment.
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pumpAndSettle();
    expect(find.text('Export full backup (JSON)'), findsOneWidget);
    expect(find.text('Export expenses (CSV)'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // dismiss the menu
    await tester.pumpAndSettle();

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

    // Target the category's own budget-row text specifically ("alert at"
    // only appears there, not in the Total Min/Max stat card above it).
    final budgetRowFinder = find.textContaining('alert at');
    expect(budgetRowFinder, findsOneWidget);
    final budgetRowText = tester.widget<Text>(budgetRowFinder).data!;
    expect(budgetRowText, contains('৳3,000'));
    expect(budgetRowText, contains('৳5,000'));

    // Swap out the widget tree first, then dispose the (unowned) container
    // ourselves and pump to flush drift's cancellation timer, all while
    // still inside the test body.
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'a Min-only budget shows just Min (no range), and strikes through once spend reaches it',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(db.close);

      final foodId = await container
          .read(categoryRepositoryProvider)
          .add(name: 'Food');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BudgetSetupScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Set a Min-only budget (leave Max empty).
      await tester.tap(find.text('Set budget'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '1000');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Target the category's own budget-row text specifically ("alert at"
      // only appears there, not in the Total Min/Max stat card above it).
      final budgetTextFinder = find.textContaining('alert at');
      expect(budgetTextFinder, findsOneWidget);
      expect(tester.widget<Text>(budgetTextFinder).data, contains('৳1,000'));
      expect(
        tester.widget<Text>(budgetTextFinder).data,
        isNot(contains('–')), // no range dash when Max isn't set
      );
      Text budgetText() => tester.widget<Text>(budgetTextFinder);
      expect(budgetText().style?.decoration, isNot(TextDecoration.lineThrough));

      // Spend up to the (Min-as-ceiling) budget.
      final now = DateTime.now();
      await container.read(expenseRepositoryProvider).add(
        ExpensesCompanion.insert(categoryId: foodId, date: now, amount: 1000),
      );
      await tester.pumpAndSettle();

      expect(budgetText().style?.decoration, TextDecoration.lineThrough);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
