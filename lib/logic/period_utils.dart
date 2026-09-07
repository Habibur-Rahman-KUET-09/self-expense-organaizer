/// Pure date/period-boundary helpers used by the calculation and reporting
/// logic. Kept separate from the calculations themselves so daily allowance,
/// threshold, and projection math never has to reason about calendars.
library;

/// Number of days in [year]-[month] (1-12), accounting for leap years.
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// First moment of [year]-[month] (inclusive).
DateTime startOfMonth(int year, int month) => DateTime(year, month, 1);

/// First moment of the month after [year]-[month] (i.e. an exclusive end
/// bound for range queries).
DateTime startOfNextMonth(int year, int month) => DateTime(year, month + 1, 1);

/// How many days of [year]-[month] have elapsed as of [asOf], for the
/// "cumulative allowed to date" calculation (FR-3.2). Returns:
/// - 0 if [asOf] is before the month starts
/// - the full day count if [asOf] is after the month ends (a past month)
/// - [asOf]'s day-of-month otherwise
int daysElapsedInMonth(DateTime asOf, {required int year, required int month}) {
  final monthStart = startOfMonth(year, month);
  final nextMonthStart = startOfNextMonth(year, month);
  if (asOf.isBefore(monthStart)) return 0;
  if (!asOf.isBefore(nextMonthStart)) return daysInMonth(year, month);
  return asOf.day;
}

/// ISO week (Monday–Sunday) containing [date], as [start, endExclusive).
(DateTime start, DateTime endExclusive) weekRangeContaining(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  final start = day.subtract(Duration(days: day.weekday - DateTime.monday));
  return (start, start.add(const Duration(days: 7)));
}

/// Calendar quarter (1-4) containing 1-based [month].
int quarterOfMonth(int month) => ((month - 1) ~/ 3) + 1;

/// Quarter [quarter] (1-4) of [year], as [start, endExclusive).
(DateTime start, DateTime endExclusive) quarterRange(int year, int quarter) {
  final firstMonth = (quarter - 1) * 3 + 1;
  return (DateTime(year, firstMonth, 1), DateTime(year, firstMonth + 3, 1));
}

/// Calendar year [year], as [start, endExclusive).
(DateTime start, DateTime endExclusive) yearRange(int year) =>
    (DateTime(year, 1, 1), DateTime(year + 1, 1, 1));
