import 'package:flutter/material.dart';

/// Utilitaires pour la conversion des couleurs.
class ColorUtils {
  /// Convertit une chaîne hexadécimale en objet [Color].
  ///
  /// Formats acceptés :
  ///   - "#RGB" (ex: "#F00")
  ///   - "#RRGGBB" (ex: "#FF0000")
  ///   - "#AARRGGBB" (ex: "#80FF0000")
  ///
  /// Si la chaîne est invalide, retourne [Colors.black] par défaut.
  static Color parseColor(String hex) {
    if (hex.startsWith('#')) {
      hex = hex.substring(1);
    } else if (hex.startsWith('0x')) {
      hex = hex.substring(2);
    }

    // Gestion du format court #RGB → #RRGGBB
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }

    // Ajout de l'alpha opaque si absent
    if (hex.length == 6) {
      hex = 'FF$hex';
    }

    if (hex.length == 8) {
      final int? value = int.tryParse(hex, radix: 16);
      if (value != null) {
        return Color(value);
      }
    }

    // Couleur de secours
    return Colors.black;
  }

  /// Convertit un objet [Color] en chaîne hexadécimale au format #AARRGGBB.
  static String colorToHex(Color color) {
    final alpha = (color.a * 255).round();
    final red = (color.r * 255).round();
    final green = (color.g * 255).round();
    final blue = (color.b * 255).round();
    return '#${_toTwoDigitHex(alpha)}${_toTwoDigitHex(red)}${_toTwoDigitHex(green)}${_toTwoDigitHex(blue)}';
  }

  /// Convertit un entier en chaîne hexadécimale sur deux caractères.
  static String _toTwoDigitHex(int value) {
    return value.toRadixString(16).padLeft(2, '0').toUpperCase();
  }
}