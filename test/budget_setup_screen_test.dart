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

    // Swap out the widget tree first, then dispose the (unowned) container
    // ourselves and pump to flush drift's cancellation timer, all while
    // still inside the test body.
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
