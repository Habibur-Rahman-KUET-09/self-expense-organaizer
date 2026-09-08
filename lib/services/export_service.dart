import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database.dart';

/// NFR-6: manual CSV/JSON export as the Phase 1 backup mechanism (no
/// backend/cloud storage). A JSON export of every table doubles as a
/// restorable backup; the CSV is a spreadsheet-friendly expense export for
/// the Reports screen.
class ExportService {
  ExportService(this._db);

  final AppDatabase _db;

  /// Exposed (not just used internally by [shareJsonBackup]) so tests can
  /// verify the export content without touching the platform share channel.
  Future<String> buildJsonBackup() async {
    final categories = await _db.select(_db.categories).get();
    final budgets = await _db.select(_db.budgets).get();
    final expenses = await _db.select(_db.expenses).get();
    final alerts = await _db.select(_db.alerts).get();

    final payload = {
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': categories.map((c) => c.toJson()).toList(),
      'budgets': budgets.map((b) => b.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'alerts': alerts.map((a) => a.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Exposed for the same reason as [buildJsonBackup].
  Future<String> buildExpensesCsv() async {
    final expenses = await (_db.select(_db.expenses)
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .get();
    final categories = await _db.select(_db.categories).get();
    final categoryNames = {for (final c in categories) c.id: c.name};

    final buffer = StringBuffer('Date,Category,Amount,Note\n');
    for (final expense in expenses) {
      final date = expense.date.toIso8601String().split('T').first;
      final category = _csvField(categoryNames[expense.categoryId] ?? 'Unknown');
      final note = _csvField(expense.note ?? '');
      buffer.writeln('$date,$category,${expense.amount},$note');
    }
    return buffer.toString();
  }

  String _csvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<File> _writeToTempFile(String content, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    return file.writeAsString(content);
  }

  /// Full backup (categories, budgets, expenses, alerts) as JSON — restoring
  /// from it isn't implemented yet in Phase 1, but the file is a complete,
  /// human-readable snapshot suitable for that later.
  Future<void> shareJsonBackup() async {
    final json = await buildJsonBackup();
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = await _writeToTempFile(json, 'expense_tracker_backup_$stamp.json');
    await Share.shareXFiles([XFile(file.path)], text: 'Expense Tracker backup');
  }

  /// All logged expenses as a spreadsheet-friendly CSV.
  Future<void> shareExpensesCsv() async {
    final csv = await buildExpensesCsv();
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = await _writeToTempFile(csv, 'expenses_$stamp.csv');
    await Share.shareXFiles([XFile(file.path)], text: 'Expense Tracker — expenses export');
  }
}
