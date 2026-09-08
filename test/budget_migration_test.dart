import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'upgrading a pre-existing (schema v1) database preserves budgets and '
    'backfills noAlert (backward compatibility)',
    () async {
      // Hand-build the exact v1 schema (maxCost NOT NULL, no noAlert column)
      // that shipped before Min/Max became must/optional, and seed a row —
      // simulating a device that already has the app installed.
      final raw = sqlite3.sqlite3.openInMemory();
      raw.execute('''
        CREATE TABLE categories (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          parent_id INTEGER REFERENCES categories(id),
          is_active INTEGER NOT NULL DEFAULT 1,
          color_value INTEGER NOT NULL DEFAULT 1732584660,
          created_at INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE budgets (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER NOT NULL REFERENCES categories(id),
          year INTEGER NOT NULL,
          month INTEGER NOT NULL,
          min_cost REAL NOT NULL DEFAULT 0,
          max_cost REAL NOT NULL,
          threshold_percent REAL NOT NULL DEFAULT 90,
          threshold_base TEXT NOT NULL DEFAULT 'max'
        );
      ''');
      raw.execute(
        "INSERT INTO categories (id, name, created_at) VALUES (1, 'Food', 0)",
      );
      raw.execute(
        'INSERT INTO budgets '
        '(id, category_id, year, month, min_cost, max_cost, threshold_percent, threshold_base) '
        "VALUES (1, 1, 2026, 9, 3000, 5000, 80, 'max')",
      );
      raw.userVersion = 1;

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      final budgets = await db.select(db.budgets).get();

      expect(budgets, hasLength(1));
      expect(budgets.single.minCost, 3000);
      expect(budgets.single.maxCost, 5000);
      expect(budgets.single.noAlert, isFalse); // new column backfilled

      await db.close();
    },
  );
}
