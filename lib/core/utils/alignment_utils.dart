import 'package:flutter/material.dart';

/// Utilitaires pour la conversion entre les chaînes de caractères (utilisées dans le JSON)
/// et les objets [Alignment] de Flutter.
///
/// Les alignements supportés correspondent aux constantes standard de Flutter :
///   - "center"
///   - "topLeft"
///   - "topCenter"
///   - "topRight"
///   - "centerLeft"
///   - "centerRight"
///   - "bottomLeft"
///   - "bottomCenter"
///   - "bottomRight"
///
/// En cas de chaîne invalide, une exception [ArgumentError] est levée.
class AlignmentUtils {
  /// Map de correspondance entre les noms et les objets [Alignment].
  static const Map<String, Alignment> _alignmentMap = {
    'center': Alignment.center,
    'topLeft': Alignment.topLeft,
    'topCenter': Alignment.topCenter,
    'topRight': Alignment.topRight,
    'centerLeft': Alignment.centerLeft,
    'centerRight': Alignment.centerRight,
    'bottomLeft': Alignment.bottomLeft,
    'bottomCenter': Alignment.bottomCenter,
    'bottomRight': Alignment.bottomRight,
  };

  /// Convertit une chaîne de caractères en [Alignment].
  ///
  /// [value] : le nom de l'alignement (ex : "center", "topLeft").
  /// Retourne `null` si [value] est null.
  /// Lève une [ArgumentError] si la chaîne ne correspond à aucun alignement connu.
  static Alignment? parseAlignment(String? value) {
    if (value == null) return null;

    final alignment = _alignmentMap[value];
    if (alignment == null) {
      throw ArgumentError('Alignement invalide : $value');
    }
    return alignment;
  }

  /// Convertit un objet [Alignment] en sa représentation chaîne pour le JSON.
  ///
  /// Si l'objet n'est pas dans la map (cas improbable), retourne "center" par défaut.
  static String alignmentToString(Alignment alignment) {
    for (final entry in _alignmentMap.entries) {
      if (entry.value == alignment) {
        return entry.key;
      }
    }
    return 'center'; // Fallback
  }

  /// Vérifie si une chaîne est un nom d'alignement valide.
  static bool isValidAlignment(String value) {
    return _alignmentMap.containsKey(value);
  }
}