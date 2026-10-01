import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/providers/database_providers.dart';
import 'package:expense_tracker/screens/add_expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('All entries: opened from Add Expense, edit on its own page, delete, back', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(db.close);
    final food = await container.read(categoryRepositoryProvider).add(name: 'Food');
    final expenses = container.read(expenseRepositoryProvider);
    await expenses.add(ExpensesCompanion.insert(
      categoryId: food,
      date: DateTime(2026, 9, 10),
      amount: 120,
      note: const Value('tea'),
    ));
    await expenses.add(ExpensesCompanion.insert(categoryId: food, date: DateTime(2026, 8, 3), amount: 75));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AddExpenseScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All entries'));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('August 2026'), findsOneWidget);

    // Search narrows the list.
    await tester.enterText(find.byType(TextField), 'tea');
    await tester.pumpAndSettle();
    expect(find.text('August 2026'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    // Edit the September one on its own page; saving comes back here.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Expense'), findsOneWidget);
    expect(find.text('Recent Expenses'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, '150');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('All entries'), findsOneWidget);
    expect(find.text('৳150'), findsOneWidget);

    // Delete the August one.
    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('August 2026'), findsNothing);

    // Back to Add Expense.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Add Expense'), findsWidgets);
    expect(find.text('Recent Expenses'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(seconds: 5));
  });
}
