import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/logic/monthly_reports.dart';
import 'package:expense_tracker/providers/database_providers.dart';
import 'package:expense_tracker/providers/service_providers.dart';
import 'package:expense_tracker/screens/budget_setup_screen.dart';
import 'package:expense_tracker/screens/monthly_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('entries filter and CSV', () {
    final cats = {
      1: const ReportCategory(id: 1, name: 'Food'),
      2: const ReportCategory(id: 2, name: 'Groceries', parentId: 1),
      3: const ReportCategory(id: 3, name: 'Transport'),
    };
    final rows = toEntryRows([
      (date: DateTime(2026, 9, 1), amount: 500.0, categoryId: 2, note: 'rice, "miniket"'),
      (date: DateTime(2026, 9, 2), amount: 120.0, categoryId: 1, note: 'tea'),
      (date: DateTime(2026, 9, 3), amount: 60.0, categoryId: 3, note: 'bus'),
    ], cats);

    test('a top-level category includes its sub-categories', () {
      expect(rows.first.categoryLabel, 'Food › Groceries');
      expect(filterEntries(rows, const EntryFilter(categoryIds: {1})).length, 2);
      expect(filterEntries(rows, const EntryFilter(categoryIds: {2})).single.amount, 500);
      expect(filterEntries(rows, const EntryFilter(categoryIds: {3})).single.note, 'bus');
    });

    test('search and amount range narrow the entries', () {
      expect(filterEntries(rows, const EntryFilter(query: 'TEA')).single.amount, 120);
      expect(filterEntries(rows, const EntryFilter(query: 'groceries')).single.amount, 500);
      expect(filterEntries(rows, const EntryFilter(minAmount: 100, maxAmount: 200)).single.note, 'tea');
      expect(totalOf(filterEntries(rows, const EntryFilter(minAmount: 100))), 620);
    });

    test('CSV has a BOM for Excel, quotes awkward notes and ends with a total', () {
      final csv = entriesCsv(rows, month: (year: 2026, month: 9));
      expect(csv.startsWith('﻿'), isTrue);
      expect(csv, contains('Date,Category,Sub-category,Amount,Note'));
      expect(csv, contains('2026-09-01,Food,Groceries,500,"rice, ""miniket"""'));
      expect(csv, contains('Total,,,680,3 entries'));
    });
  });

  test('comparing months rolls sub-categories into their parents', () {
    final cats = {
      1: const ReportCategory(id: 1, name: 'Food'),
      2: const ReportCategory(id: 2, name: 'Groceries', parentId: 1),
      3: const ReportCategory(id: 3, name: 'Transport'),
    };
    final c = compareMonths(
      months: [(year: 2026, month: 8), (year: 2026, month: 9)],
      spendByMonth: [
        {1: 100, 2: 400},
        {2: 300, 3: 50},
      ],
      categories: cats,
    );
    expect([for (final r in c.rows) '${r.name} ${r.amounts}'], ['Food [500.0, 300.0]', 'Transport [0.0, 50.0]']);
    expect(c.totals, [500.0, 350.0]);
    final csv = comparisonCsv(c);
    expect(csv, contains('Category,August 2026,September 2026,Change (last − first)'));
    expect(csv, contains('Food,500,300,-200'));
    expect(csv, contains('Total,500,350,-150'));
  });

  group('with a database', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    });

    tearDown(() {
      container.dispose();
      db.close();
    });

    Future<void> budget(int categoryId, int month, double min, {double? max}) =>
        container.read(budgetRepositoryProvider).upsert(BudgetsCompanion.insert(
              categoryId: categoryId,
              year: 2026,
              month: month,
              minCost: Value(min),
              maxCost: Value(max),
            ));

    Future<void> spend(int categoryId, DateTime date, double amount) => container
        .read(expenseRepositoryProvider)
        .add(ExpensesCompanion.insert(categoryId: categoryId, date: date, amount: amount));

    test('a new month copies last month\'s budgets once, and never over existing ones', () async {
      final repo = container.read(budgetRepositoryProvider);
      final food = await container.read(categoryRepositoryProvider).add(name: 'Food');
      final rent = await container.read(categoryRepositoryProvider).add(name: 'Rent');
      expect(await repo.copyFromPreviousIfEmpty(2026, 10), isFalse); // nothing to copy
      await budget(food, 9, 3000, max: 4000);
      await budget(rent, 9, 10000);
      expect(await repo.copyFromPreviousIfEmpty(2026, 10), isTrue);
      final october = await repo.getForMonth(2026, 10);
      expect({for (final b in october) b.categoryId: (b.minCost, b.maxCost)}, {
        food: (3000.0, 4000.0),
        rent: (10000.0, null),
      });
      // A changed budget stays as it is.
      await budget(food, 10, 3500);
      expect(await repo.copyFromPreviousIfEmpty(2026, 10), isFalse);
      expect((await repo.getForCategoryMonth(food, 2026, 10))!.minCost, 3500);
    });

    test('budget vs actual lists categories and their sub-categories', () async {
      final cats = container.read(categoryRepositoryProvider);
      final food = await cats.add(name: 'Food');
      final groceries = await cats.add(name: 'Groceries', parentId: food);
      final eatingOut = await cats.add(name: 'Eating out', parentId: food);
      final travel = await cats.add(name: 'Travel');
      await cats.add(name: 'Unused');
      await budget(groceries, 9, 2000);
      await budget(eatingOut, 9, 1000);
      await spend(groceries, DateTime(2026, 9, 5), 1500);
      await spend(eatingOut, DateTime(2026, 9, 6), 1200);
      await spend(travel, DateTime(2026, 9, 7), 300);
      await spend(travel, DateTime(2026, 8, 7), 999); // another month

      final lines = await container.read(monthlyReportServiceProvider).budgetVsActual((year: 2026, month: 9));
      expect([for (final l in lines) (l.name, l.budget, l.actual, l.isSub, l.isOver)], [
        ('Food', 3000.0, 2700.0, false, false),
        ('Eating out', 1000.0, 1200.0, true, true),
        ('Groceries', 2000.0, 1500.0, true, false),
        ('Travel', 0.0, 300.0, false, false),
      ]);
      expect(budgetTotal(lines), 3000);
      expect(actualTotal(lines), 3000);
      final csv = budgetCsv(lines, month: (year: 2026, month: 9));
      expect(csv, contains('  › Eating out,1000,1200,-200,120%,Over budget'));
      expect(csv, contains('Travel,,300,,,No budget'));
    });
  });

  testWidgets('the budget page strikes through a category and sub-category over budget', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(db.close);
    final now = DateTime.now();
    final cats = container.read(categoryRepositoryProvider);
    final food = await cats.add(name: 'Food');
    final snacks = await cats.add(name: 'Snacks', parentId: food);
    await container.read(budgetRepositoryProvider).upsert(BudgetsCompanion.insert(
          categoryId: snacks,
          year: now.year,
          month: now.month,
          minCost: const Value(100),
        ));
    await container
        .read(expenseRepositoryProvider)
        .add(ExpensesCompanion.insert(categoryId: snacks, date: now, amount: 150));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: BudgetSetupScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Food'));
    await tester.pumpAndSettle();

    // Both names are marked; entries can still be added (nothing is disabled).
    expect(find.textContaining('over budget'), findsNWidgets(2));
    TextDecoration? decorationOf(String name) {
      TextDecoration? found;
      for (final t in tester.widgetList<RichText>(find.byType(RichText))) {
        t.text.visitChildren((span) {
          if (span is TextSpan && span.text == name) found = span.style?.decoration;
          return true;
        });
      }
      return found;
    }

    expect(decorationOf('Food'), TextDecoration.lineThrough);
    expect(decorationOf('Snacks'), TextDecoration.lineThrough);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('monthly reports show a month\'s entries and a filtered total', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(db.close);
    final now = DateTime.now();
    final cats = container.read(categoryRepositoryProvider);
    final food = await cats.add(name: 'Food');
    final bus = await cats.add(name: 'Bus');
    final expenses = container.read(expenseRepositoryProvider);
    await expenses.add(ExpensesCompanion.insert(categoryId: food, date: now, amount: 250, note: const Value('lunch')));
    await expenses.add(ExpensesCompanion.insert(categoryId: bus, date: now, amount: 40));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MonthlyReportsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('2 entries'), findsOneWidget);
    expect(find.text('lunch'), findsOneWidget);
    expect(find.text('Download (CSV)'), findsOneWidget);

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Bus'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 entries'), findsOneWidget);
    expect(find.text('lunch'), findsNothing);

    await tester.tap(find.text('Compare months'));
    await tester.pumpAndSettle();
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Food'), findsWidgets);

    await tester.tap(find.text('Budget vs actual'));
    await tester.pumpAndSettle();
    expect(find.text('Spent'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(seconds: 1));
  });
}
