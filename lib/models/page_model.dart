import '../core/errors/validation_error.dart';
import '../core/utils/json_utils.dart';
import '../core/utils/uuid_generator.dart';
import 'widget_node.dart';

/// Représentation d'une page (écran) d'un projet SketchFlutter.
///
/// Chaque page possède :
///   - un identifiant unique (`id`) pour la navigation et les références.
///   - un nom (`name`) affiché dans l'onglet Pages.
///   - un indicateur `isInitial` indiquant si c'est la page d'accueil de l'application.
///   - un widget racine (`rootWidget`) qui constitue l'arbre de widgets de la page.
///   - des liaisons logiques (`logicBindings`) associant des événements de widgets
///     à des listes de blocs logiques (sous forme de maps JSON pour l'instant).
///
/// La classe est immuable ; utilisez [copyWith] pour créer des copies modifiées.
class PageModel {
  /// Identifiant unique de la page.
  final String id;

  /// Nom lisible de la page (ex: "Accueil").
  final String name;

  /// Indique si cette page est la page initiale de l'application.
  final bool isInitial;

  /// Widget racine de la page. Ne peut pas être null.
  final WidgetNode rootWidget;

  /// Liaisons logiques : widgetId -> événement -> liste de blocs.
  /// Exemple : { "widget_button_1": { "onPressed": [ { "type": "show_snackbar", ... } ] } }
  /// Peut être vide ou null.
  final Map<String, Map<String, List<Map<String, dynamic>>>>? logicBindings;

  /// Constructeur principal.
  const PageModel({
    required this.id,
    required this.name,
    this.isInitial = false,
    required this.rootWidget,
    this.logicBindings,
  });

  /// Crée une nouvelle page avec un identifiant généré automatiquement.
  ///
  /// [name] : nom de la page.
  /// [isInitial] : si c'est la page initiale (défaut false).
  /// [rootWidget] : widget racine optionnel. Si null, un Container vide est créé.
  factory PageModel.create({
    required String name,
    bool isInitial = false,
    WidgetNode? rootWidget,
  }) {
    if (name.trim().isEmpty) {
      throw ValidationError.missingField('name');
    }
    return PageModel(
      id: UuidGenerator.generatePageId(),
      name: name.trim(),
      isInitial: isInitial,
      rootWidget: rootWidget ??
          WidgetNode.create(
            type: 'Container',
            properties: {'color': '#FFFFFFFF'},
          ),
    );
  }

  /// Crée une instance à partir d'une map JSON.
  ///
  /// [json] : la map contenant les données de la page.
  /// Lève une [ValidationError] si des champs obligatoires sont manquants ou invalides.
  factory PageModel.fromJson(Map<String, dynamic> json) {
    // Identifiant
    final String? id = JsonUtils.getString(json, 'id');
    if (id == null || id.isEmpty) {
      throw ValidationError.missingField('id', path: 'page');
    }

    // Nom
    final String? name = JsonUtils.getString(json, 'name');
    if (name == null || name.isEmpty) {
      throw ValidationError.missingField('name', path: 'page.$id');
    }

    // Page initiale
    final bool isInitial = JsonUtils.getBool(json, 'is_initial') ?? false;

    // Widget racine
    final Map<String, dynamic>? rootWidgetJson = JsonUtils.getMap(json, 'root_widget');
    final WidgetNode rootWidget;
    if (rootWidgetJson != null) {
      rootWidget = WidgetNode.fromJson(rootWidgetJson);
    } else {
      // Création d'un widget par défaut si absent (Container vide)
      rootWidget = WidgetNode.create(
        type: 'Container',
        properties: {'color': '#FFFFFFFF'},
      );
    }

    // Liaisons logiques
    Map<String, Map<String, List<Map<String, dynamic>>>>? logicBindings;
    final dynamic logicData = json['logic_bindings'];
    if (logicData != null) {
      if (logicData is Map<String, dynamic>) {
        logicBindings = {};
        logicData.forEach((widgetId, events) {
          if (events is Map<String, dynamic>) {
            final Map<String, List<Map<String, dynamic>>> eventMap = {};
            events.forEach((eventName, blocks) {
              if (blocks is List) {
                eventMap[eventName] = blocks
                    .where((block) => block is Map<String, dynamic>)
                    .map((block) => Map<String, dynamic>.from(block))
                    .toList();
              } else if (blocks != null) {
                throw ValidationError.invalidType(
                  'logic_bindings.$widgetId.$eventName',
                  'List<Map<String, dynamic>>',
                  '${blocks.runtimeType}',
                  path: 'page.$id.logic_bindings',
                );
              }
            });
            logicBindings[widgetId] = eventMap;
          } else {
            throw ValidationError.invalidType(
              'logic_bindings.$widgetId',
              'Map<String, dynamic>',
              '${events.runtimeType}',
              path: 'page.$id.logic_bindings',
            );
          }
        });
      } else {
        throw ValidationError.invalidType(
          'logic_bindings',
          'Map<String, dynamic>',
          '${logicData.runtimeType}',
          path: 'page.$id.logic_bindings',
        );
      }
    }

    return PageModel(
      id: id,
      name: name,
      isInitial: isInitial,
      rootWidget: rootWidget,
      logicBindings: logicBindings,
    );
  }

  /// Convertit la page en map JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_initial': isInitial,
      'root_widget': rootWidget.toJson(),
      if (logicBindings != null && logicBindings!.isNotEmpty)
        'logic_bindings': logicBindings,
    };
  }

  /// Crée une copie de la page en remplaçant certains champs.
  PageModel copyWith({
    String? id,
    String? name,
    bool? isInitial,
    WidgetNode? rootWidget,
    Map<String, Map<String, List<Map<String, dynamic>>>>? logicBindings,
  }) {
    return PageModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isInitial: isInitial ?? this.isInitial,
      rootWidget: rootWidget ?? this.rootWidget,
      logicBindings: logicBindings ?? this.logicBindings,
    );
  }

  /// Retourne une copie profonde de la page.
  PageModel deepCopy() {
    // Copie profonde du rootWidget
    final WidgetNode newRoot = rootWidget.deepCopy();

    // Copie profonde des logicBindings
    Map<String, Map<String, List<Map<String, dynamic>>>>? newBindings;
    if (logicBindings != null) {
      newBindings = {};
      logicBindings!.forEach((widgetId, events) {
        newBindings![widgetId] = {};
        events.forEach((eventName, blocks) {
          newBindings![widgetId]![eventName] =
              blocks.map((block) => Map<String, dynamic>.from(block)).toList();
        });
      });
    }

    return PageModel(
      id: id,
      name: name,
      isInitial: isInitial,
      rootWidget: newRoot,
      logicBindings: newBindings,
    );
  }

  /// Indique si la page est la page initiale.
  bool get isHomePage => isInitial;

  @override
  String toString() => 'PageModel(id: $id, name: $name, isInitial: $isInitial)';
}