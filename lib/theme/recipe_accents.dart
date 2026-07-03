import 'dart:io';
import 'dart:ui' as ui;
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

/// The single OmNomNom brand colour. Import this instead of redeclaring a
/// local `_brand`/`brandOrange` constant per screen.
const brandOrange = Color(0xFFF69021);

/// Returns the accent colour for a recipe.
/// When [usePhotoAccent] is false (setting toggled off), always returns brand orange.
/// Otherwise uses the pre-extracted [Recipe.accentColor], falling back to brand orange.
Color accentForRecipe(Recipe recipe, {bool usePhotoAccent = true}) {
  if (!usePhotoAccent) return brandOrange;
  final c = recipe.accentColor;
  return c != null ? Color(c) : brandOrange;
}

/// Extracts the most vibrant colour from an image file by decoding a 40×40
/// thumbnail and picking the pixel with the highest saturation at a
/// reasonable lightness. Returns null on error or if no photo exists.
Future<int?> extractAccentColorFromPath(String? imagePath) async {
  if (imagePath == null) return null;
  try {
    final bytes = await File(imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 40,
      targetHeight: 40,
    );
    final frame = await codec.getNextFrame();
    final byteData =
        await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    frame.image.dispose();
    if (byteData == null) return null;

    final buf = byteData.buffer.asUint8List();
    var bestScore = 0.0;
    var bestArgb = brandOrange.toARGB32();

    for (var i = 0; i < buf.length; i += 4) {
      final r = buf[i] / 255;
      final g = buf[i + 1] / 255;
      final b = buf[i + 2] / 255;
      final max = [r, g, b].reduce((a, b) => a > b ? a : b);
      final min = [r, g, b].reduce((a, b) => a < b ? a : b);
      final l = (max + min) / 2;
      final s = (max == min)
          ? 0.0
          : (l > 0.5
              ? (max - min) / (2 - max - min)
              : (max - min) / (max + min));
      // Reward saturation; penalise extremes of lightness (very dark or washed out).
      final score = s * (1 - (l - 0.45).abs() * 2).clamp(0.0, 1.0);
      if (score > bestScore) {
        bestScore = score;
        bestArgb = Color.fromARGB(255, buf[i], buf[i + 1], buf[i + 2]).toARGB32();
      }
    }
    return bestArgb;
  } catch (_) {
    return null;
  }
}

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
