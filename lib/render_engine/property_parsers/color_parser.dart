import 'package:flutter/material.dart';

import '../../core/utils/color_utils.dart';
import 'reference_resolver.dart';

/// Parseur de couleurs pour le moteur de rendu.
///
/// Accepte :
///   - une chaîne hexadécimale (`#RRGGBB` ou `#AARRGGBB`)
///   - une référence `@colors.xxx`
///   - un objet [Color] (retourné tel quel)
class ColorParser {
  final ReferenceResolver resolver;

  const ColorParser(this.resolver);

  /// Convertit une valeur en [Color], ou retourne [fallback] si invalide.
  Color? parse(dynamic value, {Color? fallback}) {
    if (value == null) return fallback;
    if (value is Color) return value;

    String? hex;
    if (value is String) {
      if (value.startsWith('@colors.')) {
        hex = resolver.resolveColor(value);
      } else {
        hex = value;
      }
    }

    if (hex == null) return fallback;
    try {
      return ColorUtils.parseColor(hex);
    } catch (_) {
      return fallback;
    }
  }
}