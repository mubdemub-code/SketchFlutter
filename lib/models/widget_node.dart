import '../core/errors/validation_error.dart';
import '../core/utils/json_utils.dart';
import '../core/utils/uuid_generator.dart';

/// Représentation d'un nœud de widget dans l'arbre d'interface.
///
/// Chaque nœud correspond à un widget Flutter et possède :
///   - un identifiant unique (`id`) pour le référencer dans les événements et la logique.
///   - un type (`type`) correspondant au nom du widget Flutter (ex: "Container", "Text").
///   - des propriétés (`properties`) sous forme de map JSON.
///   - soit un enfant unique (`child`), soit une liste d'enfants (`children`), selon le type.
///
/// La classe est immuable, mais fournit des méthodes de manipulation et de parcours
/// pour faciliter l'édition dans l'interface.
class WidgetNode {
  /// Identifiant unique du widget.
  final String id;

  /// Type du widget (ex: "Container", "Text", "Row", "Column", etc.).
  final String type;

  /// Propriétés du widget sous forme de map JSON.
  /// Peut être `null` si aucune propriété n'est définie.
  final Map<String, dynamic>? properties;

  /// Enfant unique du widget (si applicable).
  final WidgetNode? child;

  /// Liste des enfants du widget (si applicable).
  final List<WidgetNode>? children;

  /// Constructeur principal.
  const WidgetNode({
    required this.id,
    required this.type,
    this.properties,
    this.child,
    this.children,
  });

  /// Crée un nouveau nœud avec un identifiant généré automatiquement.
  ///
  /// [type] : type du widget.
  /// [properties] : propriétés optionnelles.
  /// [child] : enfant unique optionnel.
  /// [children] : liste d'enfants optionnelle.
  factory WidgetNode.create({
    required String type,
    Map<String, dynamic>? properties,
    WidgetNode? child,
    List<WidgetNode>? children,
  }) {
    return WidgetNode(
      id: UuidGenerator.generateWidgetId(),
      type: type,
      properties: properties,
      child: child,
      children: children,
    );
  }

  /// Crée une instance à partir d'une map JSON.
  ///
  /// [json] : la map contenant les données du nœud.
  /// Lève une [ValidationError] si des champs obligatoires sont manquants ou invalides.
  factory WidgetNode.fromJson(Map<String, dynamic> json) {
    // Identifiant
    final String? id = JsonUtils.getString(json, 'id');
    if (id == null || id.isEmpty) {
      throw ValidationError.missingField('id', path: 'widget_node');
    }

    // Type
    final String? type = JsonUtils.getString(json, 'type');
    if (type == null || type.isEmpty) {
      throw ValidationError.missingField('type', path: 'widget_node.$id');
    }

    // Propriétés
    final Map<String, dynamic>? properties = JsonUtils.getMap(json, 'properties');

    // Enfant unique
    WidgetNode? child;
    final dynamic childData = json['child'];
    if (childData != null) {
      if (childData is Map<String, dynamic>) {
        child = WidgetNode.fromJson(childData);
      } else {
        throw ValidationError.invalidType(
          'child',
          'Map<String, dynamic>',
          '${childData.runtimeType}',
          path: 'widget_node.$id',
        );
      }
    }

    // Enfants multiples
    List<WidgetNode>? children;
    final dynamic childrenData = json['children'];
    if (childrenData != null) {
      if (childrenData is List) {
        children = childrenData.map((dynamic childJson) {
          if (childJson is Map<String, dynamic>) {
            return WidgetNode.fromJson(childJson);
          } else {
            throw ValidationError.invalidType(
              'children element',
              'Map<String, dynamic>',
              '${childJson.runtimeType}',
              path: 'widget_node.$id.children',
            );
          }
        }).toList();
      } else {
        throw ValidationError.invalidType(
          'children',
          'List<Map<String, dynamic>>',
          '${childrenData.runtimeType}',
          path: 'widget_node.$id',
        );
      }
    }

    return WidgetNode(
      id: id,
      type: type,
      properties: properties,
      child: child,
      children: children,
    );
  }

  /// Convertit le nœud en map JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      if (properties != null && properties!.isNotEmpty) 'properties': properties,
      if (child != null) 'child': child!.toJson(),
      if (children != null && children!.isNotEmpty)
        'children': children!.map((e) => e.toJson()).toList(),
    };
  }

  /// Crée une copie du nœud en remplaçant certains champs.
  WidgetNode copyWith({
    String? id,
    String? type,
    Map<String, dynamic>? properties,
    WidgetNode? child,
    List<WidgetNode>? children,
  }) {
    return WidgetNode(
      id: id ?? this.id,
      type: type ?? this.type,
      properties: properties ?? this.properties,
      child: child ?? this.child,
      children: children ?? this.children,
    );
  }

  /// Retourne une version profonde de la copie (tous les sous-nœuds sont copiés).
  WidgetNode deepCopy() {
    return WidgetNode(
      id: id,
      type: type,
      properties: properties != null
          ? JsonUtils.deepCopy(properties!)
          : null,
      child: child?.deepCopy(),
      children: children?.map((e) => e.deepCopy()).toList(),
    );
  }

  /// Indique si le widget possède un enfant unique.
  bool get hasChild => child != null;

  /// Indique si le widget possède une liste d'enfants.
  bool get hasChildren => children != null && children!.isNotEmpty;

  /// Retourne le nombre total de nœuds (incluant ce nœud) dans l'arbre.
  int get totalNodeCount {
    int count = 1;
    if (child != null) {
      count += child!.totalNodeCount;
    }
    if (children != null) {
      for (final childNode in children!) {
        count += childNode.totalNodeCount;
      }
    }
    return count;
  }

  /// Parcourt l'arbre et retourne le premier nœud correspondant à [id].
  WidgetNode? findById(String id) {
    if (this.id == id) {
      return this;
    }
    if (child != null) {
      final found = child!.findById(id);
      if (found != null) return found;
    }
    if (children != null) {
      for (final childNode in children!) {
        final found = childNode.findById(id);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Parcourt l'arbre et retourne la liste de tous les nœuds (incluant ce nœud).
  List<WidgetNode> getAllNodes() {
    final List<WidgetNode> nodes = [this];
    if (child != null) {
      nodes.addAll(child!.getAllNodes());
    }
    if (children != null) {
      for (final childNode in children!) {
        nodes.addAll(childNode.getAllNodes());
      }
    }
    return nodes;
  }

  /// Remplace un nœud par un autre dans l'arbre.
  ///
  /// Retourne un nouvel arbre avec le remplacement effectué.
  /// Si l'id recherché n'est pas trouvé, retourne l'arbre inchangé.
  WidgetNode replaceNode(String id, WidgetNode newNode) {
    if (this.id == id) {
      return newNode;
    }
    if (child != null) {
      final newChild = child!.replaceNode(id, newNode);
      if (newChild != child) {
        return copyWith(child: newChild);
      }
    }
    if (children != null) {
      List<WidgetNode>? newChildren;
      for (int i = 0; i < children!.length; i++) {
        final newChild = children![i].replaceNode(id, newNode);
        if (newChild != children![i]) {
          newChildren = List.from(children!);
          newChildren[i] = newChild;
          break;
        }
      }
      if (newChildren != null) {
        return copyWith(children: newChildren);
      }
    }
    return this;
  }

  /// Supprime un nœud (et son sous-arbre) de l'arbre.
  ///
  /// Retourne `null` si le nœud courant est celui à supprimer.
  /// Sinon, retourne une copie de l'arbre sans le nœud cible.
  /// Si l'id n'est pas trouvé, retourne l'arbre inchangé.
  WidgetNode? removeNode(String id) {
    if (this.id == id) {
      return null;
    }
    if (child != null) {
      final newChild = child!.removeNode(id);
      if (newChild != child) {
        return copyWith(child: newChild);
      }
    }
    if (children != null) {
      List<WidgetNode>? newChildren;
      for (int i = 0; i < children!.length; i++) {
        final newChild = children![i].removeNode(id);
        if (newChild != children![i]) {
          newChildren = List.from(children!);
          if (newChild == null) {
            newChildren.removeAt(i);
          } else {
            newChildren[i] = newChild;
          }
          break;
        }
      }
      if (newChildren != null) {
        return copyWith(children: newChildren);
      }
    }
    return this;
  }

  @override
  String toString() => 'WidgetNode(id: $id, type: $type)';
}