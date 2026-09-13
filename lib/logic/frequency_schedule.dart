/// Habit Tracker RS §3 "Frequency" + §5's "dynamicity" — a habit's schedule
/// is stored as JSON rather than rigid columns, so this is the one place
/// that knows how to interpret it. Pure, no database dependency.
library;

import 'dart:convert';

import '../models/enums.dart';

/// True for frequency types whose target is "N times per period" rather
/// than "due on specific days" — these are evaluated per-week/per-month
/// (see streak_calculator.dart's periodBasedStreak) instead of day-by-day.
extension HabitFrequencyTypeX on HabitFrequencyType {
  bool get isCountBased =>
      this == HabitFrequencyType.timesPerWeek ||
      this == HabitFrequencyType.timesPerMonth;
}

/// Decoded, type-safe view over a habit's `frequencyConfig` JSON blob, so
/// nothing else has to hand-parse the map. The JSON shape depends on
/// [type]:
/// - [HabitFrequencyType.daily]: `{}` (no config needed)
/// - [HabitFrequencyType.daysOfWeek]: `{"days": [1, 3, 5]}` — ISO weekday
///   numbers, 1 (Monday) through 7 (Sunday)
/// - [HabitFrequencyType.timesPerWeek] / [HabitFrequencyType.timesPerMonth]:
///   `{"count": 3}` — the target number of logs within the period
/// - [HabitFrequencyType.customInterval]: `{"everyNDays": 3, "anchorDate":
///   "2026-09-01"}` — due every N days counting from the anchor date
class FrequencySchedule {
  const FrequencySchedule._(this.type, this._config);

  factory FrequencySchedule.parse(HabitFrequencyType type, String configJson) {
    final decoded = configJson.trim().isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(configJson) as Map<String, dynamic>;
    return FrequencySchedule._(type, decoded);
  }

  final HabitFrequencyType type;
  final Map<String, dynamic> _config;

  /// ISO weekday numbers (1=Mon..7=Sun). Only meaningful for [daysOfWeek].
  List<int> get daysOfWeek =>
      (_config['days'] as List?)?.cast<num>().map((n) => n.toInt()).toList() ??
      const [];

  /// Only meaningful for [HabitFrequencyType.timesPerWeek]/
  /// [HabitFrequencyType.timesPerMonth].
  int get targetCount => (_config['count'] as num?)?.toInt() ?? 1;

  /// Only meaningful for [HabitFrequencyType.customInterval].
  int get everyNDays => (_config['everyNDays'] as num?)?.toInt() ?? 1;

  /// Only meaningful for [HabitFrequencyType.customInterval].
  DateTime get anchorDate {
    final raw = _config['anchorDate'] as String?;
    return raw != null ? DateTime.parse(raw) : DateTime(2000, 1, 1);
  }

  static String encodeDaysOfWeek(List<int> days) => jsonEncode({'days': days});

  static String encodeCount(int count) => jsonEncode({'count': count});

  static String encodeCustomInterval({
    required int everyNDays,
    required DateTime anchorDate,
  }) {
    return jsonEncode({
      'everyNDays': everyNDays,
      'anchorDate': DateTime(anchorDate.year, anchorDate.month, anchorDate.day)
          .toIso8601String(),
    });
  }

  /// Whether [date] is a day this habit is expected to be logged. Always
  /// true for the count-based types ([HabitFrequencyTypeX.isCountBased]) —
  /// any day is valid progress toward that period's count, so there's no
  /// per-day "due" concept for them.
  bool isDueOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    switch (type) {
      case HabitFrequencyType.daily:
        return true;
      case HabitFrequencyType.daysOfWeek:
        return daysOfWeek.contains(day.weekday);
      case HabitFrequencyType.customInterval:
        final anchor = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
        final n = everyNDays <= 0 ? 1 : everyNDays;
        final diff = day.difference(anchor).inDays;
        return diff >= 0 && diff % n == 0;
      case HabitFrequencyType.timesPerWeek:
      case HabitFrequencyType.timesPerMonth:
        return true;
    }
  }
}
