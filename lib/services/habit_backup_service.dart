import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database.dart';
import 'backup_service.dart' show InvalidBackupException;

/// The Habit Tracker module's own independent backup/restore — deliberately
/// separate from BackupService (the expense tracker's), by product
/// decision: the two modules' data shouldn't be bundled into one file, so
/// backing up/restoring one never touches the other's tables.
class HabitBackupService {
  HabitBackupService(this._db);

  final AppDatabase _db;

  /// Exposed (not just used internally by [shareJsonBackup]) so tests can
  /// verify the export content without touching the platform share channel.
  Future<String> buildJsonBackup() async {
    final habitCategories = await _db.select(_db.habitCategories).get();
    final habits = await _db.select(_db.habits).get();
    final habitLogs = await _db.select(_db.habitLogs).get();

    final payload = {
      'exportedAt': DateTime.now().toIso8601String(),
      'habitCategories': habitCategories.map((c) => c.toJson()).toList(),
      'habits': habits.map((h) => h.toJson()).toList(),
      'habitLogs': habitLogs.map((l) => l.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<File> _writeToTempFile(String content, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    return file.writeAsString(content);
  }

  /// Full habit backup (categories, habits, logs) as JSON — restorable via
  /// [restoreFromJson].
  Future<void> shareJsonBackup() async {
    final json = await buildJsonBackup();
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = await _writeToTempFile(json, 'habit_backup_$stamp.json');
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Habit backup'),
    );
  }

  /// Restores every habit table from a [buildJsonBackup]-shaped JSON
  /// string, **replacing all current habit data** — a full restore, not a
  /// merge, so original row IDs (and the category/log FKs) stay intact.
  /// Throws [InvalidBackupException] if [jsonContent] isn't recognizable as
  /// one of this app's habit backups, without touching the database.
  Future<HabitRestoreSummary> restoreFromJson(String jsonContent) async {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
    } on FormatException {
      throw InvalidBackupException('That file isn\'t valid JSON.');
    }

    for (final key in const ['habitCategories', 'habits', 'habitLogs']) {
      if (decoded[key] is! List) {
        throw InvalidBackupException(
          'That file doesn\'t look like a Habit backup (missing "$key").',
        );
      }
    }

    final List<HabitCategory> habitCategories;
    final List<Habit> habits;
    final List<HabitLog> habitLogs;
    try {
      habitCategories = (decoded['habitCategories'] as List)
          .map((e) => HabitCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      habits = (decoded['habits'] as List)
          .map((e) => Habit.fromJson(e as Map<String, dynamic>))
          .toList();
      habitLogs = (decoded['habitLogs'] as List)
          .map((e) => HabitLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw InvalidBackupException('That backup file is corrupted ($e).');
    }

    await _db.transaction(() async {
      await _db.delete(_db.habitLogs).go();
      await _db.delete(_db.habits).go();
      await _db.delete(_db.habitCategories).go();

      for (final category in habitCategories) {
        await _db.into(_db.habitCategories).insert(category);
      }
      for (final habit in habits) {
        await _db.into(_db.habits).insert(habit);
      }
      for (final log in habitLogs) {
        await _db.into(_db.habitLogs).insert(log);
      }
    });

    return HabitRestoreSummary(
      habitCategories: habitCategories.length,
      habits: habits.length,
      habitLogs: habitLogs.length,
    );
  }
}

class HabitRestoreSummary {
  const HabitRestoreSummary({
    required this.habitCategories,
    required this.habits,
    required this.habitLogs,
  });

  final int habitCategories;
  final int habits;
  final int habitLogs;
}
