/// Section 7 calculations #3–#4, and the FR-4.5 severity ladder. Pure
/// functions over plain numbers — no database dependency.
library;

import '../models/enums.dart';

/// Section 7 #3: Threshold Trigger Value = Threshold Base (Min or Max) ×
/// Threshold %.
double thresholdTriggerValue({
  required double thresholdBaseValue,
  required double thresholdPercent,
}) {
  return thresholdBaseValue * (thresholdPercent / 100);
}

/// Picks minCost or maxCost as the threshold base per the budget's
/// [ThresholdBase] setting (FR-4.2).
double resolveThresholdBase({
  required ThresholdBase base,
  required double minCost,
  required double maxCost,
}) {
  return base == ThresholdBase.min ? minCost : maxCost;
}

/// Section 7 #4: Alert Condition = Cumulative Actual Spend ≥ Threshold
/// Trigger Value.
bool isThresholdBreached({
  required double cumulativeActual,
  required double triggerValue,
}) {
  return cumulativeActual >= triggerValue;
}

/// FR-4.5 severity ladder, expressed as how far [cumulativeActual] has
/// progressed toward/past the alert [triggerValue] (not the raw budget) —
/// e.g. at 80% of the way to your configured alert point you get an early
/// "approaching" warning, and crossing it flips to "reached"/"exceeded".
/// Returns null when there's nothing to warn about yet.
///
/// This is the natural reading of FR-4.5 that stays consistent no matter
/// what threshold percentage the user configured (80%, 90%, 110%, ...):
/// the 80/100 bands below measure progress toward *that* trigger, not
/// toward the raw min/max budget.
AlertType? classifySeverity({
  required double cumulativeActual,
  required double triggerValue,
}) {
  if (triggerValue <= 0) return null;
  final percentOfTrigger = (cumulativeActual / triggerValue) * 100;
  if (percentOfTrigger < 80) return null;
  if (percentOfTrigger < 100) return AlertType.approaching;
  // Treat anything within half a percentage point of the trigger as
  // "just reached" rather than "exceeded" — an exact 100.0% match on
  // floating-point currency sums is unlikely otherwise.
  if (percentOfTrigger <= 100.5) return AlertType.reached;
  return AlertType.exceeded;
}
