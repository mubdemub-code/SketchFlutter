import 'package:flutter/material.dart';

import 'color_utils.dart';

/// Utilitaires pour la conversion entre le format JSON et les objets [TextStyle].
///
/// Formats JSON acceptés :
///   - une chaîne de référence vers le design system : `"@text_styles.title"`
///   - un objet JSON avec les propriétés suivantes (toutes optionnelles) :
///     ```json
///     {
///       "fontSize": 18.0,
///       "fontWeight": "bold",              // normal, bold, 100..900
///       "fontStyle": "italic",             // normal, italic
///       "color": "#FF000000",              // couleur hexadécimale
///       "letterSpacing": 1.2,
///       "height": 1.5,
///       "decoration": "underline",         // none, underline, lineThrough, overline
///       "textAlign": "center",             // left, right, center, justify
///       "fontFamily": "Roboto"
///     }
///     ```
class TextStyleUtils {
  /// Convertit une valeur JSON en [TextStyle].
  ///
  /// [value] : peut être un [String] (référence `@text_styles.xxx`) ou un [Map].
  /// [designSystem] : le design system global (obligatoire si on utilise des références).
  ///
  /// Retourne `null` si [value] est null.
  static TextStyle? parseTextStyle(
    dynamic value, {
    Map<String, dynamic>? designSystem,
  }) {
    if (value == null) return null;

    // Cas 1 : référence @text_styles.xxx
    if (value is String) {
      if (value.startsWith('@text_styles.')) {
        final styleName = value.substring('@text_styles.'.length);
        if (designSystem == null || designSystem['text_styles'] == null) {
          throw ArgumentError(
            'Design system non fourni pour résoudre la référence : $value',
          );
        }
        final styles = designSystem['text_styles'] as Map<String, dynamic>?;
        if (styles == null || !styles.containsKey(styleName)) {
          throw ArgumentError('Style de texte introuvable : $styleName');
        }
        return parseTextStyle(
          styles[styleName],
          designSystem: designSystem,
        );
      } else {
        // Chaîne brute non supportée (on attend un Map)
        throw ArgumentError('Format TextStyle String invalide : $value');
      }
    }

    // Cas 2 : objet JSON
    if (value is Map<String, dynamic>) {
      return _parseMap(value, designSystem);
    }

    throw ArgumentError('Format TextStyle invalide : $value');
  }

  /// Convertit un objet [TextStyle] en sa représentation JSON (Map).
  static Map<String, dynamic> textStyleToJson(TextStyle style) {
    return {
      if (style.fontSize != null) 'fontSize': style.fontSize,
      if (style.fontWeight != null) 'fontWeight': _fontWeightToString(style.fontWeight!),
      if (style.fontStyle != null) 'fontStyle': _fontStyleToString(style.fontStyle!),
      if (style.color != null) 'color': ColorUtils.colorToHex(style.color!),
      if (style.letterSpacing != null) 'letterSpacing': style.letterSpacing,
      if (style.height != null) 'height': style.height,
      if (style.decoration != null) 'decoration': _decorationToString(style.decoration!),
      if (style.fontFamily != null) 'fontFamily': style.fontFamily,
    };
  }

  // --- Helpers privés ---------------------------------------------------

  static TextStyle _parseMap(
    Map<String, dynamic> map,
    Map<String, dynamic>? designSystem,
  ) {
    // Résolution des références imbriquées pour la couleur
    Color? color;
    if (map['color'] != null) {
      String colorHex = map['color'] as String;
      // Si la couleur est une référence @colors.xxx, on la résout
      if (colorHex.startsWith('@colors.')) {
        if (designSystem == null || designSystem['colors'] == null) {
          throw ArgumentError(
            'Design system non fourni pour résoudre la couleur : $colorHex',
          );
        }
        final colorName = colorHex.substring('@colors.'.length);
        final colors = designSystem['colors'] as Map<String, dynamic>?;
        if (colors == null || !colors.containsKey(colorName)) {
          throw ArgumentError('Couleur introuvable : $colorName');
        }
        colorHex = colors[colorName] as String;
      }
      color = ColorUtils.parseColor(colorHex);
    }

    return TextStyle(
      fontSize: _parseDouble(map['fontSize']),
      fontWeight: _parseFontWeight(map['fontWeight']),
      fontStyle: _parseFontStyle(map['fontStyle']),
      color: color,
      letterSpacing: _parseDouble(map['letterSpacing']),
      height: _parseDouble(map['height']),
      decoration: _parseTextDecoration(map['decoration']),
      fontFamily: map['fontFamily'] as String?,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    throw ArgumentError('Valeur numérique invalide : $value');
  }

  static FontWeight? _parseFontWeight(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return FontWeight.values.firstWhere(
        (w) => w.value == value,
        orElse: () => FontWeight.normal,
      );
    }
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'normal':
          return FontWeight.normal;
        case 'bold':
          return FontWeight.bold;
        case 'w100':
        case '100':
          return FontWeight.w100;
        case 'w200':
        case '200':
          return FontWeight.w200;
        case 'w300':
        case '300':
          return FontWeight.w300;
        case 'w400':
        case '400':
          return FontWeight.w400;
        case 'w500':
        case '500':
          return FontWeight.w500;
        case 'w600':
        case '600':
          return FontWeight.w600;
        case 'w700':
        case '700':
          return FontWeight.w700;
        case 'w800':
        case '800':
          return FontWeight.w800;
        case 'w900':
        case '900':
          return FontWeight.w900;
        default:
          throw ArgumentError('FontWeight invalide : $value');
      }
    }
    throw ArgumentError('Type non supporté pour fontWeight : $value');
  }

  static FontStyle? _parseFontStyle(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'normal':
          return FontStyle.normal;
        case 'italic':
          return FontStyle.italic;
        default:
          throw ArgumentError('FontStyle invalide : $value');
      }
    }
    throw ArgumentError('Type non supporté pour fontStyle : $value');
  }

  static TextDecoration? _parseTextDecoration(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'none':
          return TextDecoration.none;
        case 'underline':
          return TextDecoration.underline;
        case 'linethrough':
        case 'line_through':
          return TextDecoration.lineThrough;
        case 'overline':
          return TextDecoration.overline;
        default:
          throw ArgumentError('TextDecoration invalide : $value');
      }
    }
    throw ArgumentError('Type non supporté pour decoration : $value');
  }

  static String _fontWeightToString(FontWeight weight) {
    if (weight == FontWeight.normal) return 'normal';
    if (weight == FontWeight.bold) return 'bold';
    return weight.value.toString();
  }

  static String _fontStyleToString(FontStyle style) {
    return style == FontStyle.italic ? 'italic' : 'normal';
  }

  static String _decorationToString(TextDecoration decoration) {
    if (decoration == TextDecoration.underline) return 'underline';
    if (decoration == TextDecoration.lineThrough) return 'lineThrough';
    if (decoration == TextDecoration.overline) return 'overline';
    return 'none';
  }
}