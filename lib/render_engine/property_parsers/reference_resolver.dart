import '../../models/design_system.dart';

/// Résolveur de références pour le moteur de rendu.
///
/// Les références sont des chaînes commençant par `@` :
///   - `@colors.primary`      → couleur depuis le design system.
///   - `@text_styles.title`   → style de texte global.
///   - `@spacing.medium`      → espacement global.
///   - `@variables.var_id`    → valeur courante d'une variable.
///
/// Le resolver est immuable et configuré avec le [DesignSystem] et les
/// valeurs de variables actuelles. Il fournit des méthodes pour résoudre
/// chaque type de référence, ou retourne la valeur brute si elle n'est
/// pas une référence.
class ReferenceResolver {
  /// Design system global (couleurs, styles, espacements).
  final DesignSystem designSystem;

  /// Valeurs courantes des variables (clé = variableId, valeur).
  final Map<String, dynamic> variables;

  const ReferenceResolver({
    required this.designSystem,
    required this.variables,
  });

  /// Vérifie si une valeur est une référence.
  static bool isReference(dynamic value) {
    return value is String && value.startsWith('@');
  }

  /// Résout une valeur quelconque.
  /// Si la valeur est une référence, elle est résolue ; sinon elle est
  /// retournée telle quelle.
  dynamic resolve(dynamic value) {
    if (value is! String) return value;
    if (value.startsWith('@colors.')) {
      return resolveColor(value);
    } else if (value.startsWith('@text_styles.')) {
      return resolveTextStyle(value);
    } else if (value.startsWith('@spacing.')) {
      return resolveSpacing(value);
    } else if (value.startsWith('@variables.')) {
      return resolveVariable(value);
    }
    return value;
  }

  /// Résout une référence de couleur.
  String? resolveColor(String reference) {
    if (!reference.startsWith('@colors.')) return null;
    final name = reference.substring('@colors.'.length);
    return designSystem.getColor(name);
  }

  /// Résout une référence de style de texte.
  Map<String, dynamic>? resolveTextStyle(String reference) {
    if (!reference.startsWith('@text_styles.')) return null;
    final name = reference.substring('@text_styles.'.length);
    return designSystem.getTextStyle(name);
  }

  /// Résout une référence d'espacement.
  double? resolveSpacing(String reference) {
    if (!reference.startsWith('@spacing.')) return null;
    final name = reference.substring('@spacing.'.length);
    return designSystem.getSpacing(name);
  }

  /// Résout une référence de variable.
  dynamic resolveVariable(String reference) {
    if (!reference.startsWith('@variables.')) return null;
    final varId = reference.substring('@variables.'.length);
    return variables[varId];
  }

  /// Résout une valeur en tant que couleur (gère les références).
  /// Retourne la chaîne hexadécimale ou `null` si introuvable.
  String? resolveColorValue(dynamic value) {
    if (value is String && value.startsWith('@colors.')) {
      return resolveColor(value);
    }
    return value as String?;
  }

  /// Résout une valeur en tant que style de texte (gère les références).
  Map<String, dynamic>? resolveTextStyleValue(dynamic value) {
    if (value is String && value.startsWith('@text_styles.')) {
      return resolveTextStyle(value);
    }
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  /// Résout une valeur en tant qu'espacement (gère les références).
  double? resolveSpacingValue(dynamic value) {
    if (value is String && value.startsWith('@spacing.')) {
      return resolveSpacing(value);
    }
    if (value is num) return value.toDouble();
    return null;
  }

  /// Résout une valeur en tant que variable (gère les références).
  dynamic resolveVariableValue(dynamic value) {
    if (value is String && value.startsWith('@variables.')) {
      return resolveVariable(value);
    }
    return value;
  }
}