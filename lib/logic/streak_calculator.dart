/// Habit Tracker RS §3 "Streak" + §4.3. Pure functions over plain
/// dates/counts — no database dependency, mirrors threshold_checker.dart's
/// and trend_projection.dart's style.
library;

import 'period_utils.dart';

typedef StreakResult = ({int current, int longest});

/// Streak for a day-scheduled habit (daily/daysOfWeek/customInterval — see
/// FrequencySchedule). Only days where [isDue] is true count towards the
/// streak; a due day must also satisfy [isCompleted] to extend it. Days
/// that aren't due are skipped without breaking anything.
///
/// Walking forward from [startDate] to [asOf]: a completed due day extends
/// the running streak, a missed due day resets it to zero, and the value
/// left over at the end is exactly the "current streak as of asOf" — the
/// run of completed due-days trailing the most recent due day. Callers
/// deciding whether "today" should be allowed to stay pending without
/// zeroing the streak (e.g. before some cutoff time) should pass
/// yesterday as [asOf] instead — this function itself applies no such
/// grace period.
StreakResult dayBasedStreak({
  required DateTime startDate,
  required DateTime asOf,
  required bool Function(DateTime day) isDue,
  required bool Function(DateTime day) isCompleted,
}) {
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final end = DateTime(asOf.year, asOf.month, asOf.day);
  if (end.isBefore(start)) return (current: 0, longest: 0);

  var longest = 0;
  var running = 0;
  for (var day = start; !day.isAfter(end); day = day.add(const Duration(days: 1))) {
    if (!isDue(day)) continue;
    if (isCompleted(day)) {
      running += 1;
      if (running > longest) longest = running;
    } else {
      running = 0;
    }
  }
  return (current: running, longest: longest);
}

/// Streak for a period-scheduled habit (timesPerWeek/timesPerMonth): a
/// period counts as met if [countInRange] for it is >= [targetCount].
/// [periodRanges] must be ordered oldest-first (see [weeklyPeriodRanges]/
/// [monthlyPeriodRanges]) and is expected to cover the habit's whole
/// history through "as of" — the last range's completeness (or not) is
/// exactly what drives the returned current streak, same reasoning as
/// [dayBasedStreak].
StreakResult periodBasedStreak({
  required List<(DateTime start, DateTime endExclusive)> periodRanges,
  required int Function(DateTime start, DateTime endExclusive) countInRange,
  required int targetCount,
}) {
  var longest = 0;
  var running = 0;
  for (final (start, endExclusive) in periodRanges) {
    if (countInRange(start, endExclusive) >= targetCount) {
      running += 1;
      if (running > longest) longest = running;
    } else {
      running = 0;
    }
  }
  return (current: running, longest: longest);
}

/// Weekly (Mon-Sun) period ranges from [startDate]'s week through [asOf]'s
/// week, oldest first.
List<(DateTime, DateTime)> weeklyPeriodRanges(DateTime startDate, DateTime asOf) {
  final ranges = <(DateTime, DateTime)>[];
  var (cursorStart, cursorEnd) = weekRangeContaining(startDate);
  final (_, lastEnd) = weekRangeContaining(asOf);
  while (cursorStart.isBefore(lastEnd)) {
    ranges.add((cursorStart, cursorEnd));
    cursorStart = cursorEnd;
    cursorEnd = cursorStart.add(const Duration(days: 7));
  }
  return ranges;
}

/// Monthly period ranges from [startDate]'s month through [asOf]'s month,
/// oldest first.
List<(DateTime, DateTime)> monthlyPeriodRanges(DateTime startDate, DateTime asOf) {
  final ranges = <(DateTime, DateTime)>[];
  var y = startDate.year;
  var m = startDate.month;
  final endY = asOf.year;
  final endM = asOf.month;
  while (y < endY || (y == endY && m <= endM)) {
    ranges.add((startOfMonth(y, m), startOfNextMonth(y, m)));
    final next = shiftMonth(y, m, 1);
    y = next.$1;
    m = next.$2;
  }
  return ranges;
}
