/// The month-wise reports: one month's entries (optionally filtered), two or
/// more months compared by category, and budget vs actual per category —
/// each as rows for the screen and as CSV to download. Pure functions over
/// plain values, so they're easy to test.
library;

import 'package:intl/intl.dart';

/// A category as the reports need it.
class ReportCategory {
  const ReportCategory({required this.id, required this.name, this.parentId});

  final int id;
  final String name;

  /// Null for a top-level category.
  final int? parentId;
}

/// One expense with the names it is shown under.
class EntryRow {
  const EntryRow({
    required this.date,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    this.parentId,
    this.parentName,
    this.note,
  });

  final DateTime date;
  final double amount;
  final int categoryId;
  final String categoryName;
  final int? parentId;
  final String? parentName;
  final String? note;

  /// The top-level category this entry counts under.
  int get topCategoryId => parentId ?? categoryId;

  /// "Food › Groceries" for a sub-category, "Food" otherwise.
  String get categoryLabel => parentName == null ? categoryName : '$parentName › $categoryName';
}

/// Filters for the entries report. Picking a top-level category includes
/// its sub-categories.
class EntryFilter {
  const EntryFilter({this.categoryIds = const {}, this.query = '', this.minAmount, this.maxAmount});

  final Set<int> categoryIds;
  final String query;
  final double? minAmount;
  final double? maxAmount;

  bool get isEmpty => categoryIds.isEmpty && query.trim().isEmpty && minAmount == null && maxAmount == null;

  bool matches(EntryRow row) {
    if (categoryIds.isNotEmpty &&
        !categoryIds.contains(row.categoryId) &&
        !(row.parentId != null && categoryIds.contains(row.parentId))) {
      return false;
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty &&
        !(row.note ?? '').toLowerCase().contains(q) &&
        !row.categoryLabel.toLowerCase().contains(q)) {
      return false;
    }
    if (minAmount != null && row.amount < minAmount!) return false;
    if (maxAmount != null && row.amount > maxAmount!) return false;
    return true;
  }
}

List<EntryRow> filterEntries(List<EntryRow> rows, EntryFilter filter) =>
    filter.isEmpty ? rows : [for (final r in rows) if (filter.matches(r)) r];

double totalOf(Iterable<EntryRow> rows) => rows.fold(0, (sum, r) => sum + r.amount);

/// Builds [EntryRow]s from raw expenses (date, amount, categoryId, note).
List<EntryRow> toEntryRows(
  Iterable<({DateTime date, double amount, int categoryId, String? note})> expenses,
  Map<int, ReportCategory> categories,
) {
  return [
    for (final e in expenses)
      if (categories[e.categoryId] case final c?)
        EntryRow(
          date: e.date,
          amount: e.amount,
          categoryId: c.id,
          categoryName: c.name,
          parentId: c.parentId,
          parentName: c.parentId == null ? null : categories[c.parentId]?.name,
          note: e.note,
        ),
  ];
}

/// Spend per top-level category: a sub-category's spend counts under its
/// parent.
Map<int, double> rollUpByTopCategory(Map<int, double> byCategory, Map<int, ReportCategory> categories) {
  final out = <int, double>{};
  byCategory.forEach((id, amount) {
    final top = categories[id]?.parentId ?? id;
    out[top] = (out[top] ?? 0) + amount;
  });
  return out;
}

/// A calendar month.
typedef YearMonth = ({int year, int month});

String monthLabel(YearMonth m) => DateFormat.yMMMM().format(DateTime(m.year, m.month));

/// Two or more months side by side, one row per top-level category.
class MonthComparison {
  MonthComparison({required this.months, required this.rows, required this.totals});

  final List<YearMonth> months;

  /// (category name, amount per month in [months] order)
  final List<({String name, List<double> amounts})> rows;
  final List<double> totals;

  /// Change from the first month to the last, per row.
  static double change(List<double> amounts) => amounts.isEmpty ? 0 : amounts.last - amounts.first;
}

/// [spendByMonth]: per month (in [months] order) the spend per category id
/// (sub-categories included; they're rolled into their parents here).
MonthComparison compareMonths({
  required List<YearMonth> months,
  required List<Map<int, double>> spendByMonth,
  required Map<int, ReportCategory> categories,
}) {
  final rolled = [for (final m in spendByMonth) rollUpByTopCategory(m, categories)];
  final ids = {for (final m in rolled) ...m.keys}.toList()
    ..sort((a, b) => (categories[a]?.name ?? '').toLowerCase().compareTo((categories[b]?.name ?? '').toLowerCase()));
  final rows = [
    for (final id in ids)
      (name: categories[id]?.name ?? '#$id', amounts: [for (final m in rolled) m[id] ?? 0.0]),
  ];
  final totals = [for (final m in rolled) m.values.fold<double>(0, (s, v) => s + v)];
  return MonthComparison(months: months, rows: rows, totals: totals);
}

/// One line of the budget vs actual report.
class BudgetLine {
  const BudgetLine({required this.name, required this.budget, required this.actual, this.isSub = false});

  final String name;

  /// The effective ceiling (Max if set, else Min); 0 when no budget.
  final double budget;
  final double actual;
  final bool isSub;

  double get remaining => budget - actual;
  bool get hasBudget => budget > 0;
  bool get isOver => hasBudget && actual > budget;

  /// Spend as a percentage of the budget, or null without one.
  double? get percent => hasBudget ? actual / budget * 100 : null;
}

double budgetTotal(Iterable<BudgetLine> lines) => lines.where((l) => !l.isSub).fold(0, (s, l) => s + l.budget);
double actualTotal(Iterable<BudgetLine> lines) => lines.where((l) => !l.isSub).fold(0, (s, l) => s + l.actual);

// ---------------------------------------------------------------- CSV

String _cell(Object? value) {
  final s = value == null ? '' : '$value';
  return s.contains(RegExp(r'[",\n\r]')) ? '"${s.replaceAll('"', '""')}"' : s;
}

String _amount(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// CSV text with a byte-order mark, so Excel reads Bangla and other
/// non-English names correctly.
String toCsv(List<List<Object?>> rows) => '﻿${rows.map((r) => r.map(_cell).join(',')).join('\r\n')}\r\n';

String entriesCsv(List<EntryRow> rows, {required YearMonth month, EntryFilter filter = const EntryFilter()}) {
  final date = DateFormat('yyyy-MM-dd');
  return toCsv([
    ['Expenses', monthLabel(month), if (!filter.isEmpty) '(filtered)'],
    ['Date', 'Category', 'Sub-category', 'Amount', 'Note'],
    for (final r in rows)
      [
        date.format(r.date),
        r.parentName ?? r.categoryName,
        r.parentName == null ? '' : r.categoryName,
        _amount(r.amount),
        r.note ?? '',
      ],
    ['Total', '', '', _amount(totalOf(rows)), '${rows.length} entries'],
  ]);
}

String comparisonCsv(MonthComparison c) {
  final twoOrMore = c.months.length >= 2;
  return toCsv([
    ['Category', for (final m in c.months) monthLabel(m), if (twoOrMore) 'Change (last − first)'],
    for (final r in c.rows)
      [r.name, for (final a in r.amounts) _amount(a), if (twoOrMore) _amount(MonthComparison.change(r.amounts))],
    ['Total', for (final t in c.totals) _amount(t), if (twoOrMore) _amount(MonthComparison.change(c.totals))],
  ]);
}

String budgetCsv(List<BudgetLine> lines, {required YearMonth month}) {
  final budget = budgetTotal(lines), actual = actualTotal(lines);
  return toCsv([
    ['Budget vs actual', monthLabel(month)],
    ['Category', 'Budget', 'Actual', 'Remaining', '% used', 'Status'],
    for (final l in lines)
      [
        l.isSub ? '  › ${l.name}' : l.name,
        l.hasBudget ? _amount(l.budget) : '',
        _amount(l.actual),
        l.hasBudget ? _amount(l.remaining) : '',
        l.percent == null ? '' : '${l.percent!.round()}%',
        !l.hasBudget ? 'No budget' : (l.isOver ? 'Over budget' : 'Within budget'),
      ],
    ['Total', _amount(budget), _amount(actual), _amount(budget - actual), budget > 0 ? '${(actual / budget * 100).round()}%' : '', ''],
  ]);
}
