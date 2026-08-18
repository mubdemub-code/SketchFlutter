/// Gestion des versions du format de schéma JSON des projets SketchFlutter.
///
/// Chaque projet exporté ou importé contient un champ `schema_version` à la racine.
/// Ce champ permet de faire évoluer le format au fil du temps tout en assurant
/// la rétrocompatibilité grâce à des migrations automatiques.
///
/// La version actuelle est la plus récente supportée par l'application.
/// Lors de l'importation d'un projet plus ancien, la fonction [migrate]
/// transforme les données pour les rendre compatibles avec la version courante.
class SchemaVersions {
  SchemaVersions._(); // Classe non instanciable

  /// Version actuelle du schéma JSON.
  static const String currentVersion = '1.0';

  /// Versions supportées par l'application (dans l'ordre croissant).
  /// Utilisée pour valider les projets importés.
  static const List<String> supportedVersions = [
    '0.9', // version préliminaire
    '1.0',
  ];

  /// Vérifie si une version donnée est supportée.
  static bool isSupported(String version) {
    return supportedVersions.contains(version);
  }

  /// Vérifie si une version donnée est égale à la version actuelle.
  static bool isCurrent(String version) => version == currentVersion;

  /// Migre un projet JSON vers la version actuelle.
  ///
  /// [project] : le projet JSON à migrer. Doit contenir un champ `schema_version`.
  /// Retourne le projet migré (modifié en place ou copie).
  /// Lève une [ArgumentError] si la version est absente ou non supportée.
  static Map<String, dynamic> migrate(Map<String, dynamic> project) {
    final String? version = project['schema_version'] as String?;
    if (version == null) {
      throw ArgumentError('Champ schema_version manquant dans le projet.');
    }

    if (!isSupported(version)) {
      throw ArgumentError('Version de schéma non supportée : $version');
    }

    // Copie profonde pour éviter de modifier l'original
    Map<String, dynamic> current = Map<String, dynamic>.from(project);

    // Chaîne de migrations : 0.9 → 1.0 → (futures versions)
    if (version == '0.9') {
      current = _migrateFrom0_9To1_0(current);
    }
    // Ajouter ici les migrations futures (ex: if (version == '1.0') ...)

    // S'assurer que la version est à jour
    current['schema_version'] = currentVersion;
    return current;
  }

  // ---------------------------------------------------------------------------
  // Migrations spécifiques
  // ---------------------------------------------------------------------------

  /// Migration de la version 0.9 vers 1.0.
  ///
  /// Changements principaux entre 0.9 et 1.0 :
  ///   - Le champ `root` des pages est renommé en `root_widget`.
  ///   - La clé `logic` dans les pages est renommée en `logic_bindings`.
  ///   - Les couleurs passent du format `#RRGGBB` (sans alpha) à `#AARRGGBB` (avec alpha).
  ///   - Les propriétés `padding` et `margin` deviennent des objets EdgeInsets (au lieu de simples nombres).
  ///
  /// Cette migration est fournie à titre d'exemple ; elle peut être adaptée
  /// selon l'évolution réelle du format.
  static Map<String, dynamic> _migrateFrom0_9To1_0(Map<String, dynamic> project) {
    // 1. Migration des pages
    if (project['pages'] is List) {
      final List<dynamic> pages = project['pages'] as List<dynamic>;
      for (final dynamic page in pages) {
        if (page is Map<String, dynamic>) {
          // Renommer 'root' en 'root_widget'
          if (page.containsKey('root')) {
            page['root_widget'] = page['root'];
            page.remove('root');
          }
          // Renommer 'logic' en 'logic_bindings'
          if (page.containsKey('logic')) {
            page['logic_bindings'] = page['logic'];
            page.remove('logic');
          }
        }
      }
    }

    // 2. Migration des couleurs dans tout l'arbre de widgets
    //    On parcourt récursivement les widgets pour modifier les valeurs de couleur.
    if (project['pages'] is List) {
      final List<dynamic> pages = project['pages'] as List<dynamic>;
      for (final dynamic page in pages) {
        if (page is Map<String, dynamic> && page['root_widget'] is Map<String, dynamic>) {
          _migrateColorsInWidget(page['root_widget'] as Map<String, dynamic>);
        }
      }
    }

    // 3. Migration des propriétés EdgeInsets (de simples nombres vers objets)
    if (project['pages'] is List) {
      final List<dynamic> pages = project['pages'] as List<dynamic>;
      for (final dynamic page in pages) {
        if (page is Map<String, dynamic> && page['root_widget'] is Map<String, dynamic>) {
          _migrateEdgeInsetsInWidget(page['root_widget'] as Map<String, dynamic>);
        }
      }
    }

    // 4. Mise à jour de la version (sera fait dans migrate())
    return project;
  }

  /// Migre les couleurs dans un widget et ses enfants.
  static void _migrateColorsInWidget(Map<String, dynamic> widget) {
    final Map<String, dynamic>? props =
        widget['properties'] as Map<String, dynamic>?;
    if (props != null) {
      // Couleurs simples : color, backgroundColor, textColor, borderColor, etc.
      const List<String> colorKeys = [
        'color',
        'backgroundColor',
        'textColor',
        'borderColor',
        'hintColor',
        'iconColor',
      ];
      for (final String key in colorKeys) {
        if (props.containsKey(key) && props[key] is String) {
          props[key] = _addAlphaToHex(props[key] as String);
        }
      }
      // Couleurs dans le style de texte
      if (props.containsKey('style') && props['style'] is Map<String, dynamic>) {
        final Map<String, dynamic> style = props['style'] as Map<String, dynamic>;
        if (style.containsKey('color') && style['color'] is String) {
          style['color'] = _addAlphaToHex(style['color'] as String);
        }
      }
    }

    // Récursion sur child et children
    if (widget.containsKey('child') && widget['child'] is Map<String, dynamic>) {
      _migrateColorsInWidget(widget['child'] as Map<String, dynamic>);
    }
    if (widget.containsKey('children') && widget['children'] is List) {
      for (final dynamic child in widget['children']) {
        if (child is Map<String, dynamic>) {
          _migrateColorsInWidget(child);
        }
      }
    }
  }

  /// Migre les EdgeInsets simples (nombres) vers des objets { "all": nombre }.
  static void _migrateEdgeInsetsInWidget(Map<String, dynamic> widget) {
    final Map<String, dynamic>? props =
        widget['properties'] as Map<String, dynamic>?;
    if (props != null) {
      const List<String> edgeInsetsKeys = ['padding', 'margin'];
      for (final String key in edgeInsetsKeys) {
        if (props.containsKey(key) && props[key] is num) {
          final num value = props[key] as num;
          props[key] = {'all': value.toDouble()};
        }
        // Si c'était déjà une chaîne "horizontal,vertical" on la convertit aussi
        else if (props.containsKey(key) && props[key] is String) {
          final String str = props[key] as String;
          if (str.contains(',')) {
            final parts = str.split(',').map((e) => e.trim()).toList();
            if (parts.length == 2) {
              props[key] = {
                'horizontal': double.tryParse(parts[0]) ?? 0,
                'vertical': double.tryParse(parts[1]) ?? 0,
              };
            } else {
              props[key] = {'all': double.tryParse(str) ?? 0};
            }
          } else {
            props[key] = {'all': double.tryParse(str) ?? 0};
          }
        }
      }
    }

    // Récursion sur child et children
    if (widget.containsKey('child') && widget['child'] is Map<String, dynamic>) {
      _migrateEdgeInsetsInWidget(widget['child'] as Map<String, dynamic>);
    }
    if (widget.containsKey('children') && widget['children'] is List) {
      for (final dynamic child in widget['children']) {
        if (child is Map<String, dynamic>) {
          _migrateEdgeInsetsInWidget(child);
        }
      }
    }
  }

  /// Ajoute l'alpha `FF` à une couleur hex sans alpha.
  static String _addAlphaToHex(String hex) {
    String cleaned = hex.trim();
    if (cleaned.startsWith('#')) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.length == 6) {
      return '#FF$cleaned'.toUpperCase();
    }
    // Si déjà 8 caractères (avec alpha) ou autre, on ne change rien.
    return hex;
  }
}