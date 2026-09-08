import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database.dart';

/// Thrown when a file handed to [BackupService.restoreFromJson] isn't a
/// recognizable backup (wrong shape, corrupted, or from something else).
class InvalidBackupException implements Exception {
  InvalidBackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// NFR-6: manual CSV/JSON export as the Phase 1 backup mechanism (no
/// backend/cloud storage), plus restoring from that same JSON backup.
class BackupService {
  BackupService(this._db);

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

  /// Full backup (categories, budgets, expenses, alerts) as JSON —
  /// restorable via [restoreFromJson].
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

  /// Restores every table from a [buildJsonBackup]-shaped JSON string,
  /// **replacing all current data** — this is a full restore, not a merge,
  /// so original row IDs (and the foreign keys between tables) stay intact.
  /// Throws [InvalidBackupException] if [jsonContent] isn't recognizable as
  /// one of this app's backups, without touching the database.
  Future<RestoreSummary> restoreFromJson(String jsonContent) async {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
    } on FormatException {
      throw InvalidBackupException('That file isn\'t valid JSON.');
    }

    for (final key in const ['categories', 'budgets', 'expenses', 'alerts']) {
      if (decoded[key] is! List) {
        throw InvalidBackupException(
          'That file doesn\'t look like an Expense Tracker backup '
          '(missing "$key").',
        );
      }
    }

    final List<Category> categories;
    final List<Budget> budgets;
    final List<Expense> expenses;
    final List<Alert> alerts;
    try {
      categories = (decoded['categories'] as List)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
      budgets = (decoded['budgets'] as List)
          .map((e) => Budget.fromJson(e as Map<String, dynamic>))
          .toList();
      expenses = (decoded['expenses'] as List)
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList();
      alerts = (decoded['alerts'] as List)
          .map((e) => Alert.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw InvalidBackupException('That backup file is corrupted ($e).');
    }

    // Parents (no parentId) must be inserted before their sub-categories.
    categories.sort(
      (a, b) => (a.parentId == null ? 0 : 1).compareTo(b.parentId == null ? 0 : 1),
    );

    await _db.transaction(() async {
      await _db.delete(_db.alerts).go();
      await _db.delete(_db.expenses).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.categories).go();

      for (final category in categories) {
        await _db.into(_db.categories).insert(category);
      }
      for (final budget in budgets) {
        await _db.into(_db.budgets).insert(budget);
      }
      for (final expense in expenses) {
        await _db.into(_db.expenses).insert(expense);
      }
      for (final alert in alerts) {
        await _db.into(_db.alerts).insert(alert);
      }
    });

    return RestoreSummary(
      categories: categories.length,
      budgets: budgets.length,
      expenses: expenses.length,
      alerts: alerts.length,
    );
  }
}

class RestoreSummary {
  const RestoreSummary({
    required this.categories,
    required this.budgets,
    required this.expenses,
    required this.alerts,
  });

  final int categories;
  final int budgets;
  final int expenses;
  final int alerts;
}
