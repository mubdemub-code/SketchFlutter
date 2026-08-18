import '../core/errors/validation_error.dart';
import '../core/utils/json_utils.dart';
import '../core/utils/uuid_generator.dart';

/// Représente une collection de dépendances externes (packages Flutter) utilisées
/// dans un projet SketchFlutter.
///
/// Les dépendances sont stockées dans le JSON du projet sous la forme d'une liste.
/// Chaque dépendance est représentée par un objet [Dependency].
///
/// Exemple de section JSON :
/// ```json
/// "dependencies": [
///   { "package": "http", "version": "^1.2.0" },
///   { "package": "shared_preferences", "version": "^2.2.0" }
/// ]
/// ```
///
/// La classe est immuable ; utilisez [copyWith] pour créer des copies modifiées.
class Dependencies {
  /// Liste des dépendances.
  final List<Dependency> items;

  /// Constructeur principal.
  const Dependencies({this.items = const []});

  /// Crée une instance à partir d'une map JSON.
  ///
  /// [json] : la map contenant la liste des dépendances.
  /// Le champ attendu est `dependencies` (List<Map<String, dynamic>>).
  /// Si absent, la liste est vide.
  factory Dependencies.fromJson(Map<String, dynamic> json) {
    final List<Dependency> deps = [];
    if (json.containsKey('dependencies')) {
      final dynamic depsData = json['dependencies'];
      if (depsData is List) {
        for (final dynamic depJson in depsData) {
          if (depJson is Map<String, dynamic>) {
            deps.add(Dependency.fromJson(depJson));
          } else {
            throw ValidationError.invalidType(
              'dependency element',
              'Map<String, dynamic>',
              '${depJson.runtimeType}',
              path: 'dependencies',
            );
          }
        }
      } else if (depsData != null) {
        throw ValidationError.invalidType(
          'dependencies',
          'List<Map<String, dynamic>>',
          '${depsData.runtimeType}',
          path: 'dependencies',
        );
      }
    }
    return Dependencies(items: deps);
  }

  /// Convertit la collection en map JSON.
  Map<String, dynamic> toJson() {
    return {
      if (items.isNotEmpty)
        'dependencies': items.map((e) => e.toJson()).toList(),
    };
  }

  /// Crée une copie avec remplacement de certains champs.
  Dependencies copyWith({List<Dependency>? items}) {
    return Dependencies(items: items ?? this.items);
  }

  /// Retourne une copie profonde de la collection.
  Dependencies deepCopy() {
    return Dependencies(items: items.map((e) => e.deepCopy()).toList());
  }

  /// Ajoute une dépendance (retourne une nouvelle collection).
  Dependencies add(Dependency dependency) {
    final newItems = List<Dependency>.from(items);
    // Éviter les doublons par nom de package
    final index = newItems.indexWhere((d) => d.name == dependency.name);
    if (index != -1) {
      newItems[index] = dependency; // remplace
    } else {
      newItems.add(dependency);
    }
    return Dependencies(items: newItems);
  }

  /// Supprime une dépendance par son nom (retourne une nouvelle collection).
  Dependencies remove(String packageName) {
    final newItems = items.where((d) => d.name != packageName).toList();
    return Dependencies(items: newItems);
  }

  /// Vérifie si une dépendance avec ce nom existe.
  bool contains(String packageName) {
    return items.any((d) => d.name == packageName);
  }

  /// Récupère une dépendance par son nom, ou `null`.
  Dependency? getByName(String packageName) {
    for (final dep in items) {
      if (dep.name == packageName) return dep;
    }
    return null;
  }

  /// Nombre de dépendances.
  int get length => items.length;

  /// Indique si la collection est vide.
  bool get isEmpty => items.isEmpty;

  @override
  String toString() => 'Dependencies(count: ${items.length})';
}

/// Représentation d'une dépendance externe (package Flutter).
///
/// Chaque dépendance possède :
///   - un identifiant unique (`id`) pour la gestion interne,
///   - un nom (`name`) correspondant au nom du package sur pub.dev,
///   - une version (`version`) optionnelle (ex: "^1.2.0"),
///   - un type (`type`) indiquant la source (pub, git, path),
///   - des champs optionnels selon le type : `gitUrl`, `ref`, `path`.
///
/// La classe est immuable.
class Dependency {
  /// Identifiant unique (généré automatiquement).
  final String id;

  /// Nom du package (ex: "http").
  final String name;

  /// Version du package (ex: "^1.2.0"). Peut être null pour "latest".
  final String? version;

  /// Type de dépendance (pub, git, path).
  final DependencyType type;

  /// URL du dépôt Git (si type == git).
  final String? gitUrl;

  /// Référence Git (branche, tag, commit) (si type == git).
  final String? ref;

  /// Chemin local (si type == path).
  final String? path;

  /// Constructeur principal.
  const Dependency({
    required this.id,
    required this.name,
    this.version,
    this.type = DependencyType.pub,
    this.gitUrl,
    this.ref,
    this.path,
  });

  /// Crée une dépendance avec identifiant généré automatiquement.
  ///
  /// [name] : nom du package.
  /// [version] : version (optionnel).
  /// [type] : type de dépendance (défaut pub).
  /// [gitUrl], [ref], [path] : champs optionnels selon le type.
  factory Dependency.create({
    required String name,
    String? version,
    DependencyType type = DependencyType.pub,
    String? gitUrl,
    String? ref,
    String? path,
  }) {
    if (name.trim().isEmpty) {
      throw ValidationError.missingField('name');
    }
    return Dependency(
      id: UuidGenerator.generate(),
      name: name.trim(),
      version: version,
      type: type,
      gitUrl: gitUrl,
      ref: ref,
      path: path,
    );
  }

  /// Crée une instance à partir d'une map JSON.
  ///
  /// [json] : la map contenant les données de la dépendance.
  /// Le champ `package` est utilisé comme nom principal (compatibilité avec le format
  /// standard `{ "package": "http", "version": "^1.2.0" }`).
  /// Accepte aussi `name` comme alias.
  factory Dependency.fromJson(Map<String, dynamic> json) {
    final String? id = JsonUtils.getString(json, 'id');
    final String? name = JsonUtils.getString(json, 'package') ??
        JsonUtils.getString(json, 'name');
    if (name == null || name.trim().isEmpty) {
      throw ValidationError.missingField('package', path: 'dependency');
    }

    final String? version = JsonUtils.getString(json, 'version');

    final String? typeStr = JsonUtils.getString(json, 'type');
    final DependencyType type = typeStr != null
        ? DependencyType.fromString(typeStr)
        : DependencyType.pub;

    final String? gitUrl = JsonUtils.getString(json, 'git_url');
    final String? ref = JsonUtils.getString(json, 'ref');
    final String? path = JsonUtils.getString(json, 'path');

    return Dependency(
      id: id ?? UuidGenerator.generate(),
      name: name.trim(),
      version: version,
      type: type,
      gitUrl: gitUrl,
      ref: ref,
      path: path,
    );
  }

  /// Convertit la dépendance en map JSON.
  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      // Utiliser 'package' comme clé principale pour la compatibilité
      'package': name,
      if (version != null) 'version': version,
      'type': type.name,
      if (gitUrl != null) 'git_url': gitUrl,
      if (ref != null) 'ref': ref,
      if (path != null) 'path': path,
    };
  }

  /// Crée une copie de la dépendance en remplaçant certains champs.
  Dependency copyWith({
    String? id,
    String? name,
    String? version,
    DependencyType? type,
    String? gitUrl,
    String? ref,
    String? path,
  }) {
    return Dependency(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      type: type ?? this.type,
      gitUrl: gitUrl ?? this.gitUrl,
      ref: ref ?? this.ref,
      path: path ?? this.path,
    );
  }

  /// Retourne une copie profonde (utile si les champs contiennent des structures).
  Dependency deepCopy() {
    return Dependency(
      id: id,
      name: name,
      version: version,
      type: type,
      gitUrl: gitUrl,
      ref: ref,
      path: path,
    );
  }

  /// Vérifie si la dépendance est valide (nom non vide, champs cohérents).
  bool isValid() {
    if (name.trim().isEmpty) return false;
    switch (type) {
      case DependencyType.pub:
        return true;
      case DependencyType.git:
        return gitUrl != null && gitUrl!.isNotEmpty;
      case DependencyType.path:
        return path != null && path!.isNotEmpty;
    }
  }

  @override
  String toString() => 'Dependency(name: $name, version: $version)';
}

/// Enumération des types de sources de dépendances.
enum DependencyType {
  /// Dépendance depuis pub.dev.
  pub,

  /// Dépendance depuis un dépôt Git.
  git,

  /// Dépendance depuis un chemin local.
  path;

  /// Convertit une chaîne en [DependencyType].
  /// Par défaut, retourne [DependencyType.pub] si la chaîne est inconnue.
  static DependencyType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pub':
        return DependencyType.pub;
      case 'git':
        return DependencyType.git;
      case 'path':
        return DependencyType.path;
      default:
        return DependencyType.pub;
    }
  }

  /// Convertit le type en chaîne lisible pour l'affichage.
  String get displayName {
    switch (this) {
      case DependencyType.pub:
        return 'Pub';
      case DependencyType.git:
        return 'Git';
      case DependencyType.path:
        return 'Chemin local';
    }
  }
}