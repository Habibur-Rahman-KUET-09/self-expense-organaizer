import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/providers/database_providers.dart';
import 'package:expense_tracker/screens/add_expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('add, edit, and delete an expense end-to-end (FR-5)', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(db.close);

    // Seed a category directly through the repository, as the Budget Setup
    // screen would have already created one before the user gets here.
    await container.read(categoryRepositoryProvider).add(name: 'Food', colorValue: 0xFFE53935);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AddExpenseScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Add an expense.
    await tester.enterText(find.byType(TextFormField).first, '250');
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add Expense'));
    await tester.pumpAndSettle();
    // Let the "Expense added" SnackBar finish and stop covering the list.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('৳250'), findsOneWidget);
    expect(find.textContaining('No expenses logged yet.'), findsNothing);

    // Edit it via the popup menu.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Expense'), findsOneWidget);
    final amountField = find.byType(TextFormField).first;
    await tester.enterText(amountField, '300');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    // Let the "Expense updated" SnackBar finish and stop covering the list.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('৳300'), findsOneWidget);
    expect(find.text('৳250'), findsNothing);

    // Delete it.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('No expenses logged yet.'), findsOneWidget);

    // See the "Fix widget test teardown..." commit for why this matters:
    // dispose the container ourselves, inside the test body, so drift's
    // stream-cancellation Timer gets a chance to fire before flutter_test's
    // "no pending timers" invariant check runs.
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('shows a hint instead of a form when there are no categories yet', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(db.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AddExpenseScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No categories yet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
