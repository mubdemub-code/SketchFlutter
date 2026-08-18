import 'package:flutter/material.dart';

import '../../core/utils/alignment_utils.dart';

/// Parseur d'alignement pour le moteur de rendu.
class AlignmentParser {
  const AlignmentParser();

  /// Convertit une chaîne en [Alignment], ou [fallback] si invalide.
  Alignment? parse(dynamic value, {Alignment? fallback}) {
    if (value is! String) return fallback;
    try {
      return AlignmentUtils.parseAlignment(value);
    } catch (_) {
      return fallback;
    }
  }
}