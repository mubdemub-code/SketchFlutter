import '../core/errors/validation_error.dart';
import '../core/utils/json_utils.dart';

/// Modèle de navigation entre les pages d'un projet.
///
/// Ce modèle décrit la page initiale et les routes de navigation possibles.
/// Chaque route définit un lien entre deux pages avec un type de transition
/// et une animation optionnelle.
///
/// Il est utilisé pour :
///   - le mode aperçu (exécution locale des navigations simples),
///   - le générateur de code (génération des routes Flutter),
///   - l'interface de l'éditeur (onglet Pages).
///
/// La classe est immuable ; utilisez [copyWith] pour créer des copies modifiées.
class NavigationModel {
  /// Identifiant de la page initiale (page d'accueil de l'application).
  final String initialPageId;

  /// Liste des routes de navigation.
  final List<NavigationRoute> routes;

  /// Constructeur principal.
  const NavigationModel({
    required this.initialPageId,
    this.routes = const [],
  });

  /// Crée une instance à partir d'une map JSON.
  ///
  /// [json] : la map contenant la configuration de navigation.
  /// Lève une [ValidationError] si des champs sont invalides.
  factory NavigationModel.fromJson(Map<String, dynamic> json) {
    // Page initiale
    final String? initialPageId = JsonUtils.getString(json, 'initial_page_id');
    if (initialPageId == null || initialPageId.isEmpty) {
      throw ValidationError.missingField('initial_page_id', path: 'navigation');
    }

    // Routes
    List<NavigationRoute> routes = [];
    if (json.containsKey('routes')) {
      final dynamic routesData = json['routes'];
      if (routesData is List) {
        routes = routesData.map((dynamic routeJson) {
          if (routeJson is Map<String, dynamic>) {
            return NavigationRoute.fromJson(routeJson);
          } else {
            throw ValidationError.invalidType(
              'route element',
              'Map<String, dynamic>',
              '${routeJson.runtimeType}',
              path: 'navigation.routes',
            );
          }
        }).toList();
      } else if (routesData != null) {
        throw ValidationError.invalidType(
          'routes',
          'List<Map<String, dynamic>>',
          '${routesData.runtimeType}',
          path: 'navigation.routes',
        );
      }
    }

    return NavigationModel(
      initialPageId: initialPageId,
      routes: routes,
    );
  }

  /// Convertit le modèle en map JSON.
  Map<String, dynamic> toJson() {
    return {
      'initial_page_id': initialPageId,
      if (routes.isNotEmpty)
        'routes': routes.map((e) => e.toJson()).toList(),
    };
  }

  /// Crée une copie du modèle en remplaçant certains champs.
  NavigationModel copyWith({
    String? initialPageId,
    List<NavigationRoute>? routes,
  }) {
    return NavigationModel(
      initialPageId: initialPageId ?? this.initialPageId,
      routes: routes ?? this.routes,
    );
  }

  /// Retourne une copie profonde du modèle.
  NavigationModel deepCopy() {
    return NavigationModel(
      initialPageId: initialPageId,
      routes: routes.map((e) => e.copyWith()).toList(),
    );
  }

  /// Vérifie si une route existe entre deux pages données.
  bool hasRoute(String fromPageId, String toPageId) {
    return routes.any((route) =>
        route.fromPageId == fromPageId && route.toPageId == toPageId);
  }

  /// Récupère toutes les routes partant d'une page donnée.
  List<NavigationRoute> getRoutesFrom(String pageId) {
    return routes.where((route) => route.fromPageId == pageId).toList();
  }

  @override
  String toString() =>
      'NavigationModel(initialPageId: $initialPageId, routes: ${routes.length})';
}

/// Représentation d'une route de navigation entre deux pages.
///
/// Une route définit :
///   - la page source ([fromPageId]),
///   - la page destination ([toPageId]),
///   - le type de navigation ([type]),
///   - l'animation de transition ([animation]).
///
/// Des paramètres supplémentaires peuvent être stockés dans [params].
class NavigationRoute {
  /// Identifiant de la page source.
  final String fromPageId;

  /// Identifiant de la page destination.
  final String toPageId;

  /// Type de navigation (push, replace, pop, etc.).
  final NavigationRouteType type;

  /// Animation de transition.
  final NavigationAnimation animation;

  /// Paramètres optionnels de la route (ex: arguments à passer).
  final Map<String, dynamic>? params;

  /// Constructeur principal.
  const NavigationRoute({
    required this.fromPageId,
    required this.toPageId,
    this.type = NavigationRouteType.push,
    this.animation = NavigationAnimation.none,
    this.params,
  });

  /// Crée une instance à partir d'une map JSON.
  ///
  /// [json] : la map contenant les données de la route.
  /// Lève une [ValidationError] si des champs obligatoires sont manquants.
  factory NavigationRoute.fromJson(Map<String, dynamic> json) {
    final String? fromPageId = JsonUtils.getString(json, 'from_page_id');
    if (fromPageId == null || fromPageId.isEmpty) {
      throw ValidationError.missingField('from_page_id', path: 'navigation.routes');
    }

    final String? toPageId = JsonUtils.getString(json, 'to_page_id');
    if (toPageId == null || toPageId.isEmpty) {
      throw ValidationError.missingField('to_page_id', path: 'navigation.routes');
    }

    final String? typeStr = JsonUtils.getString(json, 'type');
    final NavigationRouteType type = typeStr != null
        ? NavigationRouteType.fromString(typeStr)
        : NavigationRouteType.push;

    final String? animationStr = JsonUtils.getString(json, 'animation');
    final NavigationAnimation animation = animationStr != null
        ? NavigationAnimation.fromString(animationStr)
        : NavigationAnimation.none;

    final Map<String, dynamic>? params = JsonUtils.getMap(json, 'params');

    return NavigationRoute(
      fromPageId: fromPageId,
      toPageId: toPageId,
      type: type,
      animation: animation,
      params: params,
    );
  }

  /// Convertit la route en map JSON.
  Map<String, dynamic> toJson() {
    return {
      'from_page_id': fromPageId,
      'to_page_id': toPageId,
      'type': type.name,
      if (animation != NavigationAnimation.none) 'animation': animation.name,
      if (params != null && params!.isNotEmpty) 'params': params,
    };
  }

  /// Crée une copie de la route en remplaçant certains champs.
  NavigationRoute copyWith({
    String? fromPageId,
    String? toPageId,
    NavigationRouteType? type,
    NavigationAnimation? animation,
    Map<String, dynamic>? params,
  }) {
    return NavigationRoute(
      fromPageId: fromPageId ?? this.fromPageId,
      toPageId: toPageId ?? this.toPageId,
      type: type ?? this.type,
      animation: animation ?? this.animation,
      params: params ?? this.params,
    );
  }

  /// Copie profonde (utile car params peut contenir des structures imbriquées).
  NavigationRoute deepCopy() {
    return NavigationRoute(
      fromPageId: fromPageId,
      toPageId: toPageId,
      type: type,
      animation: animation,
      params: params != null ? JsonUtils.deepCopy(params!) : null,
    );
  }

  @override
  String toString() =>
      'NavigationRoute(from: $fromPageId, to: $toPageId, type: ${type.name})';
}

/// Enumération des types de navigation supportés.
enum NavigationRouteType {
  /// Pousse une nouvelle page sur la pile.
  push,

  /// Remplace la page courante par une nouvelle.
  replace,

  /// Dépile la page courante (retour).
  pop,

  /// Remplace toute la pile par une nouvelle page.
  pushAndRemoveUntil,

  /// Navigation vers une page nommée (si nommée).
  pushNamed;

  /// Convertit une chaîne en [NavigationRouteType].
  /// Par défaut, retourne [NavigationRouteType.push] si la chaîne est inconnue.
  static NavigationRouteType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'push':
        return NavigationRouteType.push;
      case 'replace':
        return NavigationRouteType.replace;
      case 'pop':
        return NavigationRouteType.pop;
      case 'push_and_remove_until':
        return NavigationRouteType.pushAndRemoveUntil;
      case 'push_named':
        return NavigationRouteType.pushNamed;
      default:
        return NavigationRouteType.push;
    }
  }

  /// Convertit le type en chaîne lisible pour l'affichage.
  String get displayName {
    switch (this) {
      case NavigationRouteType.push:
        return 'Pousser';
      case NavigationRouteType.replace:
        return 'Remplacer';
      case NavigationRouteType.pop:
        return 'Retour';
      case NavigationRouteType.pushAndRemoveUntil:
        return 'Pousser et vider la pile';
      case NavigationRouteType.pushNamed:
        return 'Pousser (nommé)';
    }
  }
}

/// Enumération des animations de navigation supportées.
enum NavigationAnimation {
  none,
  slide,
  fade,
  scale,
  rotation;

  /// Convertit une chaîne en [NavigationAnimation].
  /// Par défaut, retourne [NavigationAnimation.none].
  static NavigationAnimation fromString(String value) {
    switch (value.toLowerCase()) {
      case 'none':
        return NavigationAnimation.none;
      case 'slide':
        return NavigationAnimation.slide;
      case 'fade':
        return NavigationAnimation.fade;
      case 'scale':
        return NavigationAnimation.scale;
      case 'rotation':
        return NavigationAnimation.rotation;
      default:
        return NavigationAnimation.none;
    }
  }

  /// Convertit l'animation en chaîne lisible pour l'affichage.
  String get displayName {
    switch (this) {
      case NavigationAnimation.none:
        return 'Aucune';
      case NavigationAnimation.slide:
        return 'Glisser';
      case NavigationAnimation.fade:
        return 'Fondu';
      case NavigationAnimation.scale:
        return 'Zoom';
      case NavigationAnimation.rotation:
        return 'Rotation';
    }
  }
}