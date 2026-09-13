/// Habit Tracker RS §4.3 completion-rate calculations. Pure functions over
/// plain values — no database dependency.
library;

import '../models/enums.dart';

/// Whether a single day's log satisfies a habit for that day — a binary
/// habit just needs a log to exist; a quantifiable habit needs a logged
/// value, and (if the habit has one) that value to meet the target.
bool isLogComplete({
  required HabitType type,
  required double? targetValue,
  required bool hasLog,
  double? loggedValue,
}) {
  if (!hasLog) return false;
  if (type == HabitType.binary) return true;
  if (targetValue == null) return true;
  return (loggedValue ?? 0) >= targetValue;
}

/// Fraction (0.0-1.0) of due days within [start, endExclusive) that were
/// completed, for a day-scheduled habit (daily/daysOfWeek/customInterval).
/// Returns 0 if there were no due days in the range.
double dayBasedCompletionRate({
  required DateTime start,
  required DateTime endExclusive,
  required bool Function(DateTime day) isDue,
  required bool Function(DateTime day) isCompleted,
}) {
  var due = 0;
  var done = 0;
  for (var day = start; day.isBefore(endExclusive); day = day.add(const Duration(days: 1))) {
    if (!isDue(day)) continue;
    due += 1;
    if (isCompleted(day)) done += 1;
  }
  if (due == 0) return 0;
  return done / due;
}
