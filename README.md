# Expense Tracker (Phase 1)

Personal monthly expense tracker — Flutter app, on-device SQLite storage (drift),
no backend, no network dependency.

## Phase 1 scope (FR-1–FR-8 of the Requirements Specification)
- Category & sub-category management
- Per-category monthly min/max budgets with threshold %
- Daily budget breakdown (allowance, cumulative allowed vs actual)
- Threshold alerts (approaching / reached / exceeded)
- Manual expense entry
- Weekly / monthly / quarterly / yearly comparison reports
- Trend-based cost projection
- Dashboard

## Project structure
- `lib/models` — plain Dart data classes
- `lib/db` — drift database (tables, DAOs, generated code)
- `lib/repositories` — repository layer wrapping DB queries for screens
- `lib/logic` — pure calculation logic (daily allowance, thresholds, projection)
- `lib/providers` — Riverpod providers wiring repositories/logic to the UI
- `lib/screens` — app screens (budget setup, add expense, dashboard, reports)
- `lib/widgets` — reusable UI widgets

## Getting started
```
flutter pub get
flutter run
```
