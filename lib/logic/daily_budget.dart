/// Section 7 calculations #1–#2, and the FR-8.1 daily pace indicator.
/// Pure functions over plain numbers — no database or Flutter dependency —
/// so they're trivially unit-testable and reusable if Phase 2 moves this
/// logic behind a backend.
library;

/// Section 7 #1: Daily Allowance = Monthly Budget (Min or Max) ÷ Days in
/// Month.
double dailyAllowance({
  required double monthlyBudget,
  required int daysInMonth,
}) {
  if (daysInMonth <= 0) {
    throw ArgumentError.value(daysInMonth, 'daysInMonth', 'must be positive');
  }
  return monthlyBudget / daysInMonth;
}

/// Section 7 #2: Cumulative Allowed (to date) = Daily Allowance × Days
/// Elapsed.
double cumulativeAllowed({
  required double dailyAllowanceValue,
  required int daysElapsed,
}) {
  return dailyAllowanceValue * daysElapsed;
}

/// FR-8.1's "daily pace indicator (ahead/behind/on track)".
enum PaceStatus { ahead, onTrack, behind }

/// How actual spend-to-date compares to allowed spend-to-date.
///
/// [tolerance] is the fraction of [cumulativeAllowedValue] within which
/// spend counts as "on track" rather than clearly ahead/behind (default 5%,
/// since real-world spending rarely lands on the allowance to the cent).
PaceStatus paceStatus({
  required double cumulativeActual,
  required double cumulativeAllowedValue,
  double tolerance = 0.05,
}) {
  if (cumulativeAllowedValue <= 0) {
    return cumulativeActual > 0 ? PaceStatus.behind : PaceStatus.onTrack;
  }
  final band = cumulativeAllowedValue * tolerance;
  if (cumulativeActual > cumulativeAllowedValue + band) return PaceStatus.behind;
  if (cumulativeActual < cumulativeAllowedValue - band) return PaceStatus.ahead;
  return PaceStatus.onTrack;
}
