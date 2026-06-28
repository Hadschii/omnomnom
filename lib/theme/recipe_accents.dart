import 'package:flutter/material.dart';
import '../models/recipe.dart';

/// Neutral grey used for secondary/meta text throughout the recipe screens.
/// Readable on both light and dark surfaces.
const metaGrey = Color(0xFF8E8E93);

// ---- Theme-aware surfaces (iOS grouped-list look in light & dark) ----------

bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Background behind grouped cards (settings-style screens).
Color groupedBg(BuildContext c) =>
    _isDark(c) ? const Color(0xFF000000) : const Color(0xFFF5F5F7);

/// A raised card / sheet surface that sits on [groupedBg].
Color cardColor(BuildContext c) =>
    _isDark(c) ? const Color(0xFF1C1C1E) : Colors.white;

/// A subtle filled control (segmented tracks, input boxes, tonal chips).
Color subtleFill(BuildContext c) =>
    _isDark(c) ? const Color(0xFF2C2C2E) : const Color(0xFFF1F1F4);

/// Hairline divider / border between rows.
Color hairline(BuildContext c) =>
    _isDark(c) ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F4);

/// The per-recipe accent colour.
///
/// PLACEHOLDER: the design samples this from the recipe photo. Palette
/// extraction isn't wired yet, so we return the brand orange for every recipe.
/// Swap this single function for the extracted colour later.
Color accentForRecipe(Recipe recipe) => const Color(0xFFF69021);

/// Deterministic colour for a tag name (8-colour palette).
/// Returns a [Color]; use `.toARGB32()` to store in [Tag.color].
const _tagPalette = <int>[
  0xFFC0492E, 0xFF4E8A4F, 0xFF6E5BD8, 0xFFE08A2C,
  0xFFB23A6B, 0xFF2D6E8E, 0xFFF69021, 0xFF34A0E0,
];
Color tagColorFor(String name) =>
    Color(_tagPalette[name.hashCode.abs() % _tagPalette.length]);

/// Deterministic, distinct colours for ingredient groups (Sauce, Mains, …) so
/// a group reads the same wherever it appears (detail, editor, cook).
const _groupPalette = <Color>[
  Color(0xFFC0492E),
  Color(0xFF4E8A4F),
  Color(0xFF6E5BD8),
  Color(0xFFE08A2C),
  Color(0xFFB23A6B),
  Color(0xFF2D6E8E),
];

Color groupColor(String name) =>
    _groupPalette[name.hashCode.abs() % _groupPalette.length];

/// Formats a step timer (seconds) as m:ss, e.g. 30 -> "0:30", 300 -> "5:00".
String formatTimer(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
