/// App-wide constants. Currency is intentionally a single named constant
/// (RS doc Section 2.2: "assume single currency, configurable") rather than
/// a settings-driven value — Phase 1 has one user and no multi-currency
/// requirement, so a single edit point here is enough.
library;

const String currencySymbol = '৳';

/// Preset vibrant colors offered when creating/editing a category, matching
/// the mockup's category color-coding style.
const List<int> categoryColorPalette = [
  0xFFE53935, // red
  0xFFFB8C00, // orange
  0xFFFDD835, // yellow
  0xFF43A047, // green
  0xFF1E88E5, // blue
  0xFF8E24AA, // purple
  0xFFD81B60, // pink
  0xFF00897B, // teal
  0xFF6D4C41, // brown
  0xFF546E7A, // blue grey
];
