/// Section 7 calculations #5–#6, and FR-7's projection range. Pure
/// functions over plain numbers — no database dependency.
library;

/// A projected cost for a future period, with a Min–Max range rather than a
/// single fixed number (FR-7.4).
class ProjectionResult {
  const ProjectionResult({
    required this.projected,
    required this.projectedMin,
    required this.projectedMax,
  });

  final double projected;
  final double projectedMin;
  final double projectedMax;
}

/// Section 7 #5–#6: projects the next period's cost from a moving average
/// of recent actuals, adjusted upward if the most recent period overspent
/// its max budget.
///
/// - [recentActuals]: actual totals for the last N periods, **oldest
///   first**. Must be non-empty.
/// - [maxBudget]: the max budget the *last* period in [recentActuals] was
///   measured against (Section 7 #6 only applies the adjustment when that
///   period's actual exceeded it).
/// - FR-7.4 asks for a range rather than a single number; Phase 1 has no
///   statistical variance model to derive one from, so this uses a simple
///   +/-10% band around the point estimate as a placeholder — revisit if
///   you want something more rigorous (e.g. based on historical spread).
ProjectionResult projectNextPeriod({
  required List<double> recentActuals,
  required double maxBudget,
}) {
  if (recentActuals.isEmpty) {
    throw ArgumentError.value(
      recentActuals,
      'recentActuals',
      'must contain at least one period',
    );
  }

  final movingAverage =
      recentActuals.reduce((a, b) => a + b) / recentActuals.length;

  // Section 7 #6: Adjusted Projection = Previous Projection × (1 +
  // Overspend Rate), Overspend Rate = (Actual − Max) / Max, applied only
  // when Actual > Max. "Previous Projection" is read here as the moving
  // average computed above, per Section 7 #5's own description of the
  // simple trend projection as that same moving average.
  final lastActual = recentActuals.last;
  var projected = movingAverage;
  if (maxBudget > 0 && lastActual > maxBudget) {
    final overspendRate = (lastActual - maxBudget) / maxBudget;
    projected = movingAverage * (1 + overspendRate);
  }

  return ProjectionResult(
    projected: projected,
    projectedMin: projected * 0.9,
    projectedMax: projected * 1.1,
  );
}
