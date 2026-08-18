import '../core/errors/validation_error.dart';
import '../core/utils/json_utils.dart';

/// Design system global d'un projet.
///
/// Le design system stocke les valeurs réutilisables :
///   - **couleurs** (`colors`) : clé → chaîne hexadécimale (ex: `"primary": "#FF6200EE"`).
///   - **styles de texte** (`textStyles`) : clé → map de style (voir `TextStyleUtils`).
///   - **espacements** (`spacing`) : clé → nombre (ex: `"small": 8.0`).
///
/// Ces valeurs peuvent être référencées dans les propriétés des widgets via
/// le préfixe `@` (ex: `@colors.primary`, `@text_styles.title`, `@spacing.medium`).
/// La classe fournit des méthodes pour résoudre ces références.
///
/// Tous les champs sont immuables ; utilisez [copyWith] pour créer des copies modifiées.
class DesignSystem {
  /// Palette de couleurs globales (nom → hexadécimal).
  final Map<String, String> colors;

  /// Styles de texte globaux (nom → map de style TextStyle).
  final Map<String, Map<String, dynamic>> textStyles;

  /// Espacements globaux (nom → valeur numérique).
  final Map<String, double> spacing;

  /// Constructeur principal.
  const DesignSystem({
    this.colors = const {},
    this.textStyles = const {},
    this.spacing = const {},
  });

  /// Crée un design system par défaut avec des valeurs standards.
  factory DesignSystem.defaults() {
    return DesignSystem(
      colors: {
        'primary': '#FF6200EE',
        'secondary': '#FF03DAC6',
        'background': '#FFFFFFFF',
        'surface': '#FFF5F5F5',
        'error': '#FFB00020',
      },
      textStyles: {
        'body': {
          'fontSize': 16,
          'fontWeight': 'normal',
          'color': '#FF000000',
        },
        'title': {
          'fontSize': 24,
          'fontWeight': 'bold',
          'color': '#FF000000',
        },
        'caption': {
          'fontSize': 12,
          'fontWeight': 'normal',
          'color': '#FF666666',
        },
      },
      spacing: {
        'small': 8.0,
        'medium': 16.0,
        'large': 24.0,
      },
    );
  }

  /// Crée une instance à partir d'une map JSON.
  ///
  /// [json] : la map contenant le design system.
  /// Les champs `colors`, `text_styles` et `spacing` sont optionnels ;
  /// s'ils sont absents, ils seront vides.
  ///
  /// Lève une [ValidationError] si la structure est invalide.
  factory DesignSystem.fromJson(Map<String, dynamic> json) {
    // Colors
    Map<String, String> colors = {};
    if (json.containsKey('colors')) {
      final dynamic colorsData = json['colors'];
      if (colorsData is Map<String, dynamic>) {
        colors = colorsData.map(
          (key, value) => MapEntry(key, value as String),
        );
      } else if (colorsData != null) {
        throw ValidationError.invalidType(
          'colors',
          'Map<String, String>',
          '${colorsData.runtimeType}',
          path: 'design_system.colors',
        );
      }
    }

    // Text styles
    Map<String, Map<String, dynamic>> textStyles = {};
    if (json.containsKey('text_styles')) {
      final dynamic stylesData = json['text_styles'];
      if (stylesData is Map<String, dynamic>) {
        textStyles = stylesData.map(
          (key, value) {
            if (value is Map<String, dynamic>) {
              return MapEntry(key, value);
            } else {
              throw ValidationError.invalidType(
                'text_styles.$key',
                'Map<String, dynamic>',
                '${value.runtimeType}',
                path: 'design_system.text_styles',
              );
            }
          },
        );
      } else if (stylesData != null) {
        throw ValidationError.invalidType(
          'text_styles',
          'Map<String, Map<String, dynamic>>',
          '${stylesData.runtimeType}',
          path: 'design_system.text_styles',
        );
      }
    }

    // Spacing
    Map<String, double> spacing = {};
    if (json.containsKey('spacing')) {
      final dynamic spacingData = json['spacing'];
      if (spacingData is Map<String, dynamic>) {
        spacing = spacingData.map(
          (key, value) {
            if (value is num) {
              return MapEntry(key, value.toDouble());
            } else if (value is String) {
              final parsed = double.tryParse(value);
              if (parsed != null) {
                return MapEntry(key, parsed);
              } else {
                throw ValidationError.invalidValue(
                  'spacing.$key',
                  'Valeur numérique attendue',
                  path: 'design_system.spacing',
                  receivedValue: value,
                );
              }
            } else {
              throw ValidationError.invalidType(
                'spacing.$key',
                'num',
                '${value.runtimeType}',
                path: 'design_system.spacing',
              );
            }
          },
        );
      } else if (spacingData != null) {
        throw ValidationError.invalidType(
          'spacing',
          'Map<String, num>',
          '${spacingData.runtimeType}',
          path: 'design_system.spacing',
        );
      }
    }

    return DesignSystem(
      colors: colors,
      textStyles: textStyles,
      spacing: spacing,
    );
  }

  /// Convertit l'objet en map JSON.
  Map<String, dynamic> toJson() {
    return {
      'colors': colors,
      'text_styles': textStyles,
      'spacing': spacing,
    };
  }

  /// Crée une copie de l'objet en remplaçant certains champs.
  DesignSystem copyWith({
    Map<String, String>? colors,
    Map<String, Map<String, dynamic>>? textStyles,
    Map<String, double>? spacing,
  }) {
    return DesignSystem(
      colors: colors ?? this.colors,
      textStyles: textStyles ?? this.textStyles,
      spacing: spacing ?? this.spacing,
    );
  }

  // ---------------------------------------------------------------------------
  // Méthodes d'accès typées
  // ---------------------------------------------------------------------------

  /// Récupère une couleur par son nom.
  /// Retourne la couleur hexadécimale ou `null` si absente.
  String? getColor(String name) {
    return colors[name];
  }

  /// Récupère un style de texte par son nom.
  /// Retourne la map du style ou `null` si absente.
  Map<String, dynamic>? getTextStyle(String name) {
    return textStyles[name];
  }

  /// Récupère un espacement par son nom.
  /// Retourne la valeur numérique ou `null` si absente.
  double? getSpacing(String name) {
    return spacing[name];
  }

  /// Vérifie si une couleur existe.
  bool hasColor(String name) => colors.containsKey(name);

  /// Vérifie si un style de texte existe.
  bool hasTextStyle(String name) => textStyles.containsKey(name);

  /// Vérifie si un espacement existe.
  bool hasSpacing(String name) => spacing.containsKey(name);

  // ---------------------------------------------------------------------------
  // Résolution de références (@colors.xxx, @text_styles.xxx, @spacing.xxx)
  // ---------------------------------------------------------------------------

  /// Résout une référence de design system.
  ///
  /// [reference] : chaîne commençant par `@colors.`, `@text_styles.` ou `@spacing.`.
  /// Retourne la valeur correspondante ou `null` si la référence est invalide.
  dynamic resolveReference(String reference) {
    if (reference.startsWith('@colors.')) {
      final name = reference.substring('@colors.'.length);
      return getColor(name);
    } else if (reference.startsWith('@text_styles.')) {
      final name = reference.substring('@text_styles.'.length);
      return getTextStyle(name);
    } else if (reference.startsWith('@spacing.')) {
      final name = reference.substring('@spacing.'.length);
      return getSpacing(name);
    }
    return null;
  }

  /// Vérifie si une chaîne est une référence de design system.
  static bool isDesignSystemReference(String value) {
    return value.startsWith('@colors.') ||
        value.startsWith('@text_styles.') ||
        value.startsWith('@spacing.');
  }
}