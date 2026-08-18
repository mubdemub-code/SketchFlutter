import 'package:flutter/material.dart';

import '../../core/utils/edge_insets_utils.dart';
import 'reference_resolver.dart';

/// Parseur d'EdgeInsets pour le moteur de rendu.
class EdgeInsetsParser {
  final ReferenceResolver resolver;

  const EdgeInsetsParser(this.resolver);

  /// Convertit une valeur en [EdgeInsets], ou [fallback] si invalide.
  EdgeInsets? parse(dynamic value, {EdgeInsets? fallback}) {
    if (value == null) return fallback;
    // Si c'est une référence d'espacement
    if (value is String && value.startsWith('@spacing.')) {
      final spacing = resolver.resolveSpacing(value);
      if (spacing != null) return EdgeInsets.all(spacing);
      return fallback;
    }
    try {
      return EdgeInsetsUtils.parseEdgeInsets(value);
    } catch (_) {
      return fallback;
    }
  }
}