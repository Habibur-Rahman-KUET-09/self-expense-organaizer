import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/providers/database_providers.dart';
import 'package:expense_tracker/screens/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'renders all four period tabs and the category filter without error',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(db.close);

      final now = DateTime.now();
      final foodId = await container
          .read(categoryRepositoryProvider)
          .add(name: 'Food', colorValue: 0xFFE53935);
      await container.read(budgetRepositoryProvider).upsert(
        BudgetsCompanion.insert(
          categoryId: foodId,
          year: now.year,
          month: now.month,
          minCost: const Value(1000),
          maxCost: const Value(2000),
        ),
      );
      await container.read(expenseRepositoryProvider).add(
        ExpensesCompanion.insert(categoryId: foodId, date: now, amount: 500),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ReportsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Export action is present (NFR-6). Only open the menu — actually
      // selecting an item would hit share_plus's platform channel, which
      // isn't mocked in this test environment.
      expect(find.byIcon(Icons.ios_share), findsOneWidget);
      await tester.tap(find.byIcon(Icons.ios_share));
      await tester.pumpAndSettle();
      expect(find.text('Export full backup (JSON)'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10)); // dismiss the menu
      await tester.pumpAndSettle();

      // Starts on Week (no projection card there). The column of charts is
      // taller than the test viewport, so scroll each heading into view
      // before asserting on it (ListView only mounts on-screen children).
      expect(find.text('Comparison'), findsOneWidget);
      expect(find.text('Category Breakdown'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('Trend'),
        find.byType(ListView).first,
        const Offset(0, -300),
      );
      expect(find.text('Trend'), findsOneWidget);
      expect(find.text('Projection'), findsNothing);

      // Month tab has a projection card.
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Projection'),
        find.byType(ListView).first,
        const Offset(0, -300),
      );
      expect(find.text('Projection'), findsOneWidget);
      expect(find.text('Projected next period'), findsOneWidget);

      // Filtering to a single category hides the pie chart section.
      await tester.tap(find.text('All categories'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food').last);
      await tester.pumpAndSettle();
      expect(find.text('Category Breakdown'), findsNothing);

      await tester.tap(find.text('Quarter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Year'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
