import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/monthly_reports.dart';
import '../logic/period_utils.dart';
import '../models/budget_extensions.dart';
import '../repositories/budget_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/expense_repository.dart';
import 'budget_rollup_service.dart';

/// Loads the data behind the month-wise reports (see
/// lib/logic/monthly_reports.dart) and shares their CSV downloads.
class MonthlyReportService {
  MonthlyReportService(this._categoryRepo, this._expenseRepo, this._budgetRepo, this._rollup);

  final CategoryRepository _categoryRepo;
  final ExpenseRepository _expenseRepo;
  final BudgetRepository _budgetRepo;
  final BudgetRollupService _rollup;

  Future<Map<int, ReportCategory>> categories() async => {
        for (final c in await _categoryRepo.getAll())
          c.id: ReportCategory(id: c.id, name: c.name, parentId: c.parentId),
      };

  /// Every expense of [month], oldest first.
  Future<List<EntryRow>> entries(YearMonth month) async {
    final expenses = await _expenseRepo.getInRange(
      startOfMonth(month.year, month.month),
      startOfNextMonth(month.year, month.month),
    );
    return toEntryRows(
      [for (final e in expenses) (date: e.date, amount: e.amount, categoryId: e.categoryId, note: e.note)],
      await categories(),
    );
  }

  Future<MonthComparison> compare(List<YearMonth> months) async {
    final sorted = [...months]..sort((a, b) => (a.year * 12 + a.month).compareTo(b.year * 12 + b.month));
    return compareMonths(
      months: sorted,
      spendByMonth: [
        for (final m in sorted)
          await _expenseRepo.sumByCategoryInRange(startOfMonth(m.year, m.month), startOfNextMonth(m.year, m.month)),
      ],
      categories: await categories(),
    );
  }

  /// Each top-level category with a budget or spending in [month] (budget
  /// and spend include its sub-categories), followed by those of its
  /// sub-categories that have either.
  Future<List<BudgetLine>> budgetVsActual(YearMonth month) async {
    final spend = await _expenseRepo.sumByCategoryInRange(
      startOfMonth(month.year, month.month),
      startOfNextMonth(month.year, month.month),
    );
    final lines = <BudgetLine>[];
    for (final top in await _categoryRepo.getTopLevel(activeOnly: false)) {
      final budget = await _rollup.effectiveBudgetForCategory(top.id, month.year, month.month);
      final subs = await _categoryRepo.getSubCategories(top.id, activeOnly: false);
      final actual = (spend[top.id] ?? 0) + subs.fold<double>(0, (s, c) => s + (spend[c.id] ?? 0));
      final subLines = <BudgetLine>[];
      for (final sub in subs) {
        final own = await _budgetRepo.getForCategoryMonth(sub.id, month.year, month.month);
        final subSpend = spend[sub.id] ?? 0;
        if (own == null && subSpend == 0) continue;
        subLines.add(BudgetLine(name: sub.name, budget: own?.effectiveCeiling ?? 0, actual: subSpend, isSub: true));
      }
      if (!budget.hasBudget && actual == 0) continue;
      lines
        ..add(BudgetLine(name: top.name, budget: budget.hasBudget ? budget.ceiling : 0, actual: actual))
        ..addAll(subLines);
    }
    return lines;
  }

  /// Writes [csv] to a file and opens the share sheet, from where it can be
  /// saved to the phone, Drive, or sent on.
  Future<void> shareCsv(String csv, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = await File('${dir.path}/$filename').writeAsString(csv);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/csv')], text: filename));
  }
}
