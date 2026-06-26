import 'package:flutter/material.dart';
import '../models/recipe.dart';

/// Neutral grey used for secondary/meta text throughout the recipe screens.
const metaGrey = Color(0xFF8E8E93);

/// The per-recipe accent colour.
///
/// PLACEHOLDER: the design samples this from the recipe photo. Palette
/// extraction isn't wired yet, so we return the brand orange for every recipe.
/// Swap this single function for the extracted colour later.
Color accentForRecipe(Recipe recipe) => const Color(0xFFF69021);

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
