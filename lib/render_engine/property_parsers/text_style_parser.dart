import 'package:flutter/material.dart';

import '../../core/utils/text_style_utils.dart';
import 'color_parser.dart';
import 'reference_resolver.dart';

/// Parseur de style de texte pour le moteur de rendu.
class TextStyleParser {
  final ColorParser colorParser;
  final ReferenceResolver resolver;

  const TextStyleParser({
    required this.colorParser,
    required this.resolver,
  });

  /// Convertit une valeur en [TextStyle], ou [fallback] si invalide.
  TextStyle? parse(dynamic value, {TextStyle? fallback}) {
    if (value == null) return fallback;
    // Si c'est une référence @text_styles.xxx
    if (value is String && value.startsWith('@text_styles.')) {
      final styleMap = resolver.resolveTextStyle(value);
      if (styleMap != null) {
        return _parseMap(styleMap);
      }
      return fallback;
    }
    if (value is Map<String, dynamic>) {
      return _parseMap(value);
    }
    return fallback;
  }

  TextStyle? _parseMap(Map<String, dynamic> map) {
    // Résoudre la couleur via colorParser si présente
    Color? color;
    if (map.containsKey('color')) {
      color = colorParser.parse(map['color']);
    }
    return TextStyleUtils.parseTextStyle(
      {
        ...map,
        if (color != null) 'color': '#${color!.toARGB32().toRadixString(16).padLeft(8, '0')}',
      },
      designSystem: null, // les références déjà résolues
    );
  }
}