import 'dart:convert';

/// Utilitaires pour la manipulation robuste du JSON.
///
/// Ces méthodes évitent les erreurs de type et les clés manquantes lors de la lecture
/// des objets JSON représentant les projets. Elles sont utilisées dans les modèles,
/// le moteur de rendu et le générateur de code.
class JsonUtils {
  // ---------------------------------------------------------------------------
  // Parsing et encodage
  // ---------------------------------------------------------------------------

  /// Tente de parser une chaîne JSON en [Map<String, dynamic>].
  /// Retourne `null` si le parsing échoue ou si le résultat n'est pas un objet.
  static Map<String, dynamic>? tryParse(String source) {
    try {
      final dynamic decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Parse une chaîne JSON en [Map<String, dynamic>].
  /// Lève une [FormatException] si le parsing échoue.
  static Map<String, dynamic> parse(String source) {
    final dynamic decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw FormatException('Le JSON attendu doit être un objet.');
  }

  /// Encode un [Map] en chaîne JSON.
  /// Si [pretty] est vrai, la sortie est indentée pour la lisibilité.
  static String encode(Map<String, dynamic> data, {bool pretty = false}) {
    final encoder = JsonEncoder.withIndent(pretty ? '  ' : null);

    return encoder.convert(data);
  }

  // ---------------------------------------------------------------------------
  // Lectures typées avec valeurs par défaut
  // ---------------------------------------------------------------------------

  /// Lit une chaîne de caractères. Retourne [defaultValue] si la clé est absente
  /// ou si la valeur n'est pas une String.
  static String? getString(
    Map<String, dynamic> map,
    String key, {
    String? defaultValue,
  }) {
    final dynamic value = map[key];
    if (value is String) {
      return value;
    }
    return defaultValue;
  }

  /// Lit un entier. Retourne [defaultValue] si la clé est absente ou si la valeur
  /// n'est pas un int (ou convertible).
  static int? getInt(
    Map<String, dynamic> map,
    String key, {
    int? defaultValue,
  }) {
    final dynamic value = map[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Lit un nombre à virgule flottante. Retourne [defaultValue] si la clé est absente
  /// ou si la valeur n'est pas un num (ou convertible).
  static double? getDouble(
    Map<String, dynamic> map,
    String key, {
    double? defaultValue,
  }) {
    final dynamic value = map[key];
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Lit un booléen. Retourne [defaultValue] si la clé est absente ou si la valeur
  /// n'est pas un bool.
  static bool? getBool(
    Map<String, dynamic> map,
    String key, {
    bool? defaultValue,
  }) {
    final dynamic value = map[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return defaultValue;
  }

  /// Lit une liste dynamique. Retourne [defaultValue] si la clé est absente ou si
  /// la valeur n'est pas une List.
  static List<dynamic>? getList(
    Map<String, dynamic> map,
    String key, {
    List<dynamic>? defaultValue,
  }) {
    final dynamic value = map[key];
    if (value is List) {
      return value;
    }
    return defaultValue;
  }

  /// Lit un sous-objet JSON. Retourne [defaultValue] si la clé est absente ou si
  /// la valeur n'est pas un Map<String, dynamic>.
  static Map<String, dynamic>? getMap(
    Map<String, dynamic> map,
    String key, {
    Map<String, dynamic>? defaultValue,
  }) {
    final dynamic value = map[key];
    if (value is Map<String, dynamic>) {
      return value;
    }
    // Tentative de conversion si c'est un Map mais pas du bon type
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (_) {}
    }
    return defaultValue;
  }

  /// Lecture générique : retourne la valeur brute associée à [key].
  /// Utile pour les champs polymorphes.
  static T? getValue<T>(Map<String, dynamic> map, String key) {
    final dynamic value = map[key];
    if (value is T) {
      return value;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Lectures strictes (lèvent une exception si absence ou type incorrect)
  // ---------------------------------------------------------------------------

  /// Lit une valeur en exigeant sa présence et son type.
  /// Lève une [ArgumentError] si la clé est absente ou si le type ne correspond pas.
  static T requireValue<T>(Map<String, dynamic> map, String key) {
    if (!map.containsKey(key)) {
      throw ArgumentError('Clé JSON manquante : $key');
    }
    final dynamic value = map[key];
    if (value is! T) {
      throw ArgumentError(
        'Type incorrect pour la clé "$key" : attendu $T, obtenu ${value.runtimeType}',
      );
    }
    return value;
  }

  /// Lit une chaîne en exigeant sa présence.
  static String requireString(Map<String, dynamic> map, String key) {
    return requireValue<String>(map, key);
  }

  /// Lit un entier en exigeant sa présence.
  static int requireInt(Map<String, dynamic> map, String key) {
    return requireValue<int>(map, key);
  }

  /// Lit un booléen en exigeant sa présence.
  static bool requireBool(Map<String, dynamic> map, String key) {
    return requireValue<bool>(map, key);
  }

  /// Lit un double en exigeant sa présence.
  static double requireDouble(Map<String, dynamic> map, String key) {
    return requireValue<double>(map, key);
  }

  /// Lit une liste en exigeant sa présence.
  static List<dynamic> requireList(Map<String, dynamic> map, String key) {
    return requireValue<List<dynamic>>(map, key);
  }

  /// Lit un objet en exigeant sa présence.
  static Map<String, dynamic> requireMap(Map<String, dynamic> map, String key) {
    return requireValue<Map<String, dynamic>>(map, key);
  }

  // ---------------------------------------------------------------------------
  // Manipulation avancée
  // ---------------------------------------------------------------------------

  /// Copie profonde d'un [Map<String, dynamic>] (y compris les listes et sous-maps).
  /// Utile pour éviter les effets de bord lors de la modification d'un projet.
  static Map<String, dynamic> deepCopy(Map<String, dynamic> source) {
    return jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  }

  /// Supprime récursivement toutes les clés dont la valeur est `null`.
  /// Cela allège le JSON exporté.
  static void removeNulls(Map<String, dynamic> map) {
    map.removeWhere((key, value) => value == null);
    map.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        removeNulls(value);
      } else if (value is List) {
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            removeNulls(item);
          }
        }
      }
    });
  }

  /// Convertit un [Map<String, String>] en [Map<String, dynamic>].
  static Map<String, dynamic> fromStringMap(Map<String, String> source) {
    return source.map((key, value) => MapEntry(key, value as dynamic));
  }

  /// Vérifie si une clé existe et n'est pas `null`.
  static bool hasNonNull(Map<String, dynamic> map, String key) {
    return map.containsKey(key) && map[key] != null;
  }
}