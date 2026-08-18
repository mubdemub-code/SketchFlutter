import 'package:flutter/material.dart';

/// Utilitaires pour la conversion entre le format JSON et les objets [EdgeInsets].
///
/// Le format JSON accepté pour les marges/paddings est :
///   - un nombre : appliqué aux quatre côtés (ex: `16`)
///   - une chaîne : `"16"` (nombre uniforme) ou `"8,16"` (horizontal, vertical)
///   - un objet JSON :
///       * soit `{ "all": 16 }` (uniforme)
///       * soit `{ "top": 8, "bottom": 16, "left": 4, "right": 4 }`
///       * les côtés manquants sont considérés comme 0.
class EdgeInsetsUtils {
  /// Convertit une valeur JSON (num, String, Map) en [EdgeInsets].
  ///
  /// Retourne `null` si la valeur est `null`.
  static EdgeInsets? parseEdgeInsets(dynamic value) {
    if (value == null) return null;

    // Cas 1 : nombre uniforme
    if (value is num) {
      return EdgeInsets.all(value.toDouble());
    }

    // Cas 2 : chaîne de caractères
    if (value is String) {
      return _parseString(value);
    }

    // Cas 3 : objet JSON
    if (value is Map<String, dynamic>) {
      return _parseMap(value);
    }

    // Format non reconnu
    throw ArgumentError('Format EdgeInsets invalide : $value');
  }

  /// Convertit un objet [EdgeInsets] en sa représentation JSON (objet avec champs).
  static Map<String, dynamic> edgeInsetsToJson(EdgeInsets insets) {
    return {
      'top': insets.top,
      'bottom': insets.bottom,
      'left': insets.left,
      'right': insets.right,
    };
  }

  // --- Helpers privés ---------------------------------------------------

  /// Analyse une chaîne de caractères.
  static EdgeInsets _parseString(String str) {
    str = str.trim();

    // Si la chaîne est un simple nombre (ex: "16") -> uniforme
    final double? uniformValue = double.tryParse(str);
    if (uniformValue != null) {
      return EdgeInsets.all(uniformValue);
    }

    // Format "horizontal,vertical" (ex: "8,16")
    final parts = str.split(',').map((e) => e.trim()).toList();
    if (parts.length == 2) {
      final double? horizontal = double.tryParse(parts[0]);
      final double? vertical = double.tryParse(parts[1]);
      if (horizontal != null && vertical != null) {
        return EdgeInsets.symmetric(
          horizontal: horizontal,
          vertical: vertical,
        );
      }
    }

    throw ArgumentError('Chaîne EdgeInsets invalide : $str');
  }

  /// Analyse un objet Map.
  static EdgeInsets _parseMap(Map<String, dynamic> map) {
    // Vérifier si le format "all" est présent
    if (map.containsKey('all')) {
      final dynamic allValue = map['all'];
      if (allValue is num) {
        return EdgeInsets.all(allValue.toDouble());
      }
    }

    // Format avec côtés individuels
    double top = 0;
    double bottom = 0;
    double left = 0;
    double right = 0;

    if (map.containsKey('top')) {
      top = _parseSideValue(map['top']);
    }
    if (map.containsKey('bottom')) {
      bottom = _parseSideValue(map['bottom']);
    }
    if (map.containsKey('left')) {
      left = _parseSideValue(map['left']);
    }
    if (map.containsKey('right')) {
      right = _parseSideValue(map['right']);
    }

    return EdgeInsets.only(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
    );
  }

  /// Convertit une valeur de côté (num ou String) en double.
  static double _parseSideValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    } else if (value is String) {
      final double? parsed = double.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
    throw ArgumentError('Valeur de côté EdgeInsets invalide : $value');
  }
}