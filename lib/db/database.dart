import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// ignore: unused_import
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../models/enums.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Categories, Budgets, Expenses, Alerts])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  /// Used by tests to run against an in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'expense_tracker.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
