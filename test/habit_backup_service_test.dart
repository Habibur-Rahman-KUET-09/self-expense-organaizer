import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/models/enums.dart';
import 'package:expense_tracker/services/backup_service.dart' show InvalidBackupException;
import 'package:expense_tracker/services/habit_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Some tests below open a second in-memory AppDatabase on purpose (to
  // prove restore doesn't touch the wrong one) — see the equivalent note
  // in budget_rollup_and_export_test.dart.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<int> addWellnessCategory(AppDatabase target) {
    return target
        .into(target.habitCategories)
        .insert(HabitCategoriesCompanion.insert(name: 'Wellness'));
  }

  group('HabitBackupService export', () {
    test('JSON backup includes habit categories, habits, and habit logs', () async {
      final categoryId = await addWellnessCategory(db);
      final habitId = await db.into(db.habits).insert(
        HabitsCompanion.insert(
          name: 'Meditate',
          categoryId: Value(categoryId),
          type: HabitType.binary,
          frequencyType: HabitFrequencyType.daily,
          startDate: DateTime(2026, 9, 1),
        ),
      );
      await db.into(db.habitLogs).insert(
        HabitLogsCompanion.insert(habitId: habitId, logDate: DateTime(2026, 9, 1)),
      );

      final json = await HabitBackupService(db).buildJsonBackup();
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['habitCategories'], hasLength(1));
      expect((decoded['habitCategories'] as List).first['name'], 'Wellness');
      expect(decoded['habits'], hasLength(1));
      expect((decoded['habits'] as List).first['name'], 'Meditate');
      expect(decoded['habitLogs'], hasLength(1));
      // The expense tracker's own tables never appear in a habit backup —
      // the two are independent by design.
      expect(decoded.containsKey('categories'), isFalse);
      expect(decoded.containsKey('expenses'), isFalse);
    });
  });

  group('HabitBackupService restore', () {
    test('round-trips a full habit backup into a fresh database, IDs and links intact', () async {
      final categoryId = await addWellnessCategory(db);
      final habitId = await db.into(db.habits).insert(
        HabitsCompanion.insert(
          name: 'Meditate',
          categoryId: Value(categoryId),
          type: HabitType.binary,
          frequencyType: HabitFrequencyType.daily,
          startDate: DateTime(2026, 9, 1),
        ),
      );
      await db.into(db.habitLogs).insert(
        HabitLogsCompanion.insert(habitId: habitId, logDate: DateTime(2026, 9, 1)),
      );

      final json = await HabitBackupService(db).buildJsonBackup();

      final freshDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(freshDb.close);
      final summary = await HabitBackupService(freshDb).restoreFromJson(json);

      expect(summary.habitCategories, 1);
      expect(summary.habits, 1);
      expect(summary.habitLogs, 1);

      final restoredHabit = await freshDb.select(freshDb.habits).getSingle();
      expect(restoredHabit.name, 'Meditate');
      expect(restoredHabit.categoryId, categoryId); // link to Wellness preserved

      final restoredLog = await freshDb.select(freshDb.habitLogs).getSingle();
      expect(restoredLog.habitId, habitId);
    });

    test('restore replaces existing habit data rather than merging with it', () async {
      await addWellnessCategory(db);

      final otherDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(otherDb.close);
      await otherDb
          .into(otherDb.habitCategories)
          .insert(HabitCategoriesCompanion.insert(name: 'Fitness'));
      final backupFromOtherDb = await HabitBackupService(otherDb).buildJsonBackup();

      await HabitBackupService(db).restoreFromJson(backupFromOtherDb);

      final categories = await db.select(db.habitCategories).get();
      expect(categories.map((c) => c.name), ['Fitness']);
    });

    test(
      'rejects a file that isn\'t a recognizable habit backup, without touching existing data',
      () async {
        await addWellnessCategory(db);

        expect(
          () => HabitBackupService(db).restoreFromJson('{"not": "a backup"}'),
          throwsA(isA<InvalidBackupException>()),
        );
        expect(
          () => HabitBackupService(db).restoreFromJson('not even json'),
          throwsA(isA<InvalidBackupException>()),
        );
        // An expense-tracker backup (no habit keys) is also not a habit
        // backup — the two formats are independent, not interchangeable.
        expect(
          () => HabitBackupService(db).restoreFromJson(
            jsonEncode({'categories': [], 'budgets': [], 'expenses': [], 'alerts': []}),
          ),
          throwsA(isA<InvalidBackupException>()),
        );

        final categories = await db.select(db.habitCategories).get();
        expect(categories.map((c) => c.name), ['Wellness']);
      },
    );
  });
}
