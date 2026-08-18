import '../core/constants/schema_versions.dart';
import '../core/errors/validation_error.dart';
import '../core/utils/json_utils.dart';
import 'project_metadata.dart';
import 'design_system.dart';
import 'page_model.dart';
import 'variable.dart';
import 'asset_model.dart';
import 'navigation_model.dart';
import 'dependencies.dart';
import 'custom_code.dart';
import 'generation_settings.dart';

/// Modèle racine représentant un projet SketchFlutter complet.
///
/// Ce modèle agrège tous les sous-modèles (métadonnées, design system, pages,
/// variables, assets, navigation, dépendances, code personnalisé et paramètres
/// de génération). Il est sérialisable en JSON et constitue la structure de
/// sauvegarde et d'échange (fichier `.mub`).
///
/// La classe est immuable ; utilisez [copyWith] pour créer des copies modifiées
/// et [deepCopy] pour un clonage complet.
class ProjectModel {
  /// Version du schéma JSON (doit correspondre à [SchemaVersions.currentVersion]).
  final String schemaVersion;

  /// Métadonnées du projet.
  final ProjectMetadata metadata;

  /// Design system global (couleurs, styles de texte, espacements).
  final DesignSystem designSystem;

  /// Liste des pages de l'application.
  final List<PageModel> pages;

  /// Liste des variables globales.
  final List<Variable> variables;

  /// Liste des assets (images, polices, etc.).
  final List<AssetModel> assets;

  /// Configuration de navigation.
  final NavigationModel navigation;

  /// Dépendances externes (packages Flutter).
  final Dependencies dependencies;

  /// Code Dart personnalisé.
  final CustomCode customCode;

  /// Paramètres de génération de l'APK.
  final GenerationSettings generationSettings;

  /// Constructeur principal.
  const ProjectModel({
    required this.schemaVersion,
    required this.metadata,
    required this.designSystem,
    required this.pages,
    required this.variables,
    required this.assets,
    required this.navigation,
    required this.dependencies,
    required this.customCode,
    required this.generationSettings,
  });

  /// Crée un nouveau projet vide avec des valeurs par défaut.
  ///
  /// [name] : nom du projet.
  /// [description] : description optionnelle.
  /// [author] : auteur optionnel.
  /// [packageName] : nom de package Android (si null, généré à partir du nom).
  factory ProjectModel.create({
    required String name,
    String? description,
    String? author,
    String? packageName,
  }) {
    final metadata = ProjectMetadata.create(
      name: name,
      description: description,
      author: author,
    );

    // Générer un nom de package par défaut si non fourni
    String defaultPackage = packageName ?? _generatePackageName(name);
    if (packageName == null || packageName.trim().isEmpty) {
      defaultPackage = _generatePackageName(name);
    }

    return ProjectModel(
      schemaVersion: SchemaVersions.currentVersion,
      metadata: metadata,
      designSystem: DesignSystem.defaults(),
      pages: [],
      variables: [],
      assets: [],
      navigation: NavigationModel(
        initialPageId: '', // sera mis à jour quand la première page sera ajoutée
      ),
      dependencies: Dependencies(),
      customCode: CustomCode(),
      generationSettings: GenerationSettings.create(
        packageName: defaultPackage,
      ),
    );
  }

  /// Crée une instance à partir d'une map JSON.
  ///
  /// [json] : la map contenant les données du projet.
  /// Si la version du schéma est plus ancienne, une migration est tentée via
  /// [SchemaVersions.migrate].
  ///
  /// Lève une [ValidationError] en cas de champ manquant ou invalide.
  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    // Migration si nécessaire
    Map<String, dynamic> data = json;
    if (data.containsKey('schema_version')) {
      final String version = data['schema_version'] as String;
      if (version != SchemaVersions.currentVersion) {
        data = SchemaVersions.migrate(data);
      }
    } else {
      // Si pas de version, on suppose que c'est un projet très ancien -> erreur
      throw ValidationError.missingField('schema_version', path: 'project');
    }

    // Metadata
    final Map<String, dynamic>? metadataJson = JsonUtils.getMap(data, 'project_metadata');
    if (metadataJson == null) {
      throw ValidationError.missingField('project_metadata', path: 'project');
    }
    final metadata = ProjectMetadata.fromJson(metadataJson);

    // Design system
    final Map<String, dynamic>? designSystemJson = JsonUtils.getMap(data, 'design_system');
    final DesignSystem designSystem = designSystemJson != null
        ? DesignSystem.fromJson(designSystemJson)
        : DesignSystem.defaults();

    // Pages
    List<PageModel> pages = [];
    if (data.containsKey('pages')) {
      final dynamic pagesData = data['pages'];
      if (pagesData is List) {
        pages = pagesData.map((dynamic pageJson) {
          if (pageJson is Map<String, dynamic>) {
            return PageModel.fromJson(pageJson);
          } else {
            throw ValidationError.invalidType(
              'page element',
              'Map<String, dynamic>',
              '${pageJson.runtimeType}',
              path: 'project.pages',
            );
          }
        }).toList();
      } else if (pagesData != null) {
        throw ValidationError.invalidType(
          'pages',
          'List<Map<String, dynamic>>',
          '${pagesData.runtimeType}',
          path: 'project.pages',
        );
      }
    }

    // Variables
    List<Variable> variables = [];
    if (data.containsKey('variables')) {
      final dynamic varsData = data['variables'];
      if (varsData is List) {
        variables = varsData.map((dynamic varJson) {
          if (varJson is Map<String, dynamic>) {
            return Variable.fromJson(varJson);
          } else {
            throw ValidationError.invalidType(
              'variable element',
              'Map<String, dynamic>',
              '${varJson.runtimeType}',
              path: 'project.variables',
            );
          }
        }).toList();
      } else if (varsData != null) {
        throw ValidationError.invalidType(
          'variables',
          'List<Map<String, dynamic>>',
          '${varsData.runtimeType}',
          path: 'project.variables',
        );
      }
    }

    // Assets
    List<AssetModel> assets = [];
    if (data.containsKey('assets')) {
      final dynamic assetsData = data['assets'];
      if (assetsData is List) {
        assets = assetsData.map((dynamic assetJson) {
          if (assetJson is Map<String, dynamic>) {
            return AssetModel.fromJson(assetJson);
          } else {
            throw ValidationError.invalidType(
              'asset element',
              'Map<String, dynamic>',
              '${assetJson.runtimeType}',
              path: 'project.assets',
            );
          }
        }).toList();
      } else if (assetsData != null) {
        throw ValidationError.invalidType(
          'assets',
          'List<Map<String, dynamic>>',
          '${assetsData.runtimeType}',
          path: 'project.assets',
        );
      }
    }

    // Navigation
    NavigationModel navigation;
    final Map<String, dynamic>? navJson = JsonUtils.getMap(data, 'navigation');
    if (navJson != null) {
      navigation = NavigationModel.fromJson(navJson);
    } else {
      // Si pas de navigation, on peut essayer de la déduire des pages (première page initiale)
      String initialPageId = '';
      for (final page in pages) {
        if (page.isInitial) {
          initialPageId = page.id;
          break;
        }
      }
      if (initialPageId.isEmpty && pages.isNotEmpty) {
        initialPageId = pages.first.id;
      }
      navigation = NavigationModel(initialPageId: initialPageId);
    }

    // Dependencies
    Dependencies dependencies;
    final Map<String, dynamic>? depsJson = JsonUtils.getMap(data, 'dependencies');
    if (depsJson != null) {
      dependencies = Dependencies.fromJson(depsJson);
    } else {
      dependencies = Dependencies();
    }

    // Custom code
    CustomCode customCode;
    final Map<String, dynamic>? customCodeJson = JsonUtils.getMap(data, 'custom_code');
    if (customCodeJson != null) {
      customCode = CustomCode.fromJson(customCodeJson);
    } else {
      customCode = CustomCode();
    }

    // Generation settings
    GenerationSettings generationSettings;
    final Map<String, dynamic>? genSettingsJson = JsonUtils.getMap(data, 'generation_settings');
    if (genSettingsJson != null) {
      generationSettings = GenerationSettings.fromJson(genSettingsJson);
    } else {
      // Valeurs par défaut dérivées du projet
      final String defaultPackage = _generatePackageName(metadata.name);
      generationSettings = GenerationSettings.create(packageName: defaultPackage);
    }

    return ProjectModel(
      schemaVersion: SchemaVersions.currentVersion,
      metadata: metadata,
      designSystem: designSystem,
      pages: pages,
      variables: variables,
      assets: assets,
      navigation: navigation,
      dependencies: dependencies,
      customCode: customCode,
      generationSettings: generationSettings,
    );
  }

  /// Convertit le projet en map JSON.
  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'project_metadata': metadata.toJson(),
      'design_system': designSystem.toJson(),
      'pages': pages.map((e) => e.toJson()).toList(),
      'variables': variables.map((e) => e.toJson()).toList(),
      'assets': assets.map((e) => e.toJson()).toList(),
      'navigation': navigation.toJson(),
      'dependencies': dependencies.toJson(),
      'custom_code': customCode.toJson(),
      'generation_settings': generationSettings.toJson(),
    };
  }

  /// Crée une copie du projet en remplaçant certains champs.
  ProjectModel copyWith({
    String? schemaVersion,
    ProjectMetadata? metadata,
    DesignSystem? designSystem,
    List<PageModel>? pages,
    List<Variable>? variables,
    List<AssetModel>? assets,
    NavigationModel? navigation,
    Dependencies? dependencies,
    CustomCode? customCode,
    GenerationSettings? generationSettings,
  }) {
    return ProjectModel(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      metadata: metadata ?? this.metadata,
      designSystem: designSystem ?? this.designSystem,
      pages: pages ?? this.pages,
      variables: variables ?? this.variables,
      assets: assets ?? this.assets,
      navigation: navigation ?? this.navigation,
      dependencies: dependencies ?? this.dependencies,
      customCode: customCode ?? this.customCode,
      generationSettings: generationSettings ?? this.generationSettings,
    );
  }

  /// Retourne une copie profonde du projet.
  ProjectModel deepCopy() {
    return ProjectModel(
      schemaVersion: schemaVersion,
      metadata: metadata.copyWith(),
      designSystem: designSystem.copyWith(),
      pages: pages.map((e) => e.deepCopy()).toList(),
      variables: variables.map((e) => e.copyWith()).toList(),
      assets: assets.map((e) => e.copyWith()).toList(),
      navigation: navigation.deepCopy(),
      dependencies: dependencies.deepCopy(),
      customCode: customCode.deepCopy(),
      generationSettings: generationSettings.deepCopy(),
    );
  }

  // ---------------------------------------------------------------------------
  // Méthodes utilitaires
  // ---------------------------------------------------------------------------

  /// Récupère une page par son identifiant.
  PageModel? getPageById(String pageId) {
    for (final page in pages) {
      if (page.id == pageId) return page;
    }
    return null;
  }

  /// Récupère la page initiale, ou null si aucune page n'est définie.
  PageModel? get initialPage {
    for (final page in pages) {
      if (page.id == navigation.initialPageId) return page;
    }
    // Fallback : première page marquée comme initiale
    for (final page in pages) {
      if (page.isInitial) return page;
    }
    // Fallback : première page tout court
    return pages.isNotEmpty ? pages.first : null;
  }

  /// Ajoute une page et retourne une nouvelle instance du projet.
  ProjectModel addPage(PageModel page) {
    final newPages = List<PageModel>.from(pages)..add(page);
    // Si c'est la première page, on définit la navigation initiale
    if (pages.isEmpty && navigation.initialPageId.isEmpty) {
      return copyWith(
        pages: newPages,
        navigation: navigation.copyWith(initialPageId: page.id),
      );
    }
    return copyWith(pages: newPages);
  }

  /// Supprime une page par son identifiant.
  /// Retourne une nouvelle instance ; si la page était la page initiale,
  /// la première page restante devient la nouvelle initiale.
  ProjectModel removePage(String pageId) {
    final newPages = pages.where((p) => p.id != pageId).toList();
    String newInitialId = navigation.initialPageId;
    if (newInitialId == pageId) {
      newInitialId = newPages.isNotEmpty ? newPages.first.id : '';
    }
    return copyWith(
      pages: newPages,
      navigation: navigation.copyWith(initialPageId: newInitialId),
    );
  }

  /// Récupère une variable par son identifiant.
  Variable? getVariableById(String variableId) {
    for (final variable in variables) {
      if (variable.id == variableId) return variable;
    }
    return null;
  }

  /// Ajoute une variable et retourne une nouvelle instance.
  ProjectModel addVariable(Variable variable) {
    final newVariables = List<Variable>.from(variables)..add(variable);
    return copyWith(variables: newVariables);
  }

  /// Supprime une variable par son identifiant.
  ProjectModel removeVariable(String variableId) {
    final newVariables = variables.where((v) => v.id != variableId).toList();
    return copyWith(variables: newVariables);
  }

  /// Récupère un asset par son identifiant.
  AssetModel? getAssetById(String assetId) {
    for (final asset in assets) {
      if (asset.id == assetId) return asset;
    }
    return null;
  }

  /// Ajoute un asset et retourne une nouvelle instance.
  ProjectModel addAsset(AssetModel asset) {
    final newAssets = List<AssetModel>.from(assets)..add(asset);
    return copyWith(assets: newAssets);
  }

  /// Supprime un asset par son identifiant.
  ProjectModel removeAsset(String assetId) {
    final newAssets = assets.where((a) => a.id != assetId).toList();
    return copyWith(assets: newAssets);
  }

  /// Vérifie si le projet est valide (schéma cohérent, pages présentes, etc.).
  bool isValid() {
    return schemaVersion == SchemaVersions.currentVersion &&
        metadata.isValid() &&
        pages.isNotEmpty &&
        navigation.initialPageId.isNotEmpty &&
        getPageById(navigation.initialPageId) != null;
  }

  @override
  String toString() =>
      'ProjectModel(version: $schemaVersion, name: ${metadata.name}, pages: ${pages.length})';

  // ---------------------------------------------------------------------------
  // Helper privé
  // ---------------------------------------------------------------------------

  /// Génère un nom de package Android valide à partir du nom du projet.
  static String _generatePackageName(String projectName) {
    // Normaliser : minuscules, remplacer espaces et caractères invalides par des underscores
    String normalized = projectName.toLowerCase().trim();
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    if (normalized.isEmpty) normalized = 'app';
    return 'com.sketchflutter.$normalized';
  }
}