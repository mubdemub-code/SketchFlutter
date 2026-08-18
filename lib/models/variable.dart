import '../core/errors/validation_error.dart';
import '../core/utils/json_utils.dart';
import '../core/utils/uuid_generator.dart';

/// Représentation d'une variable globale dans un projet SketchFlutter.
///
/// Une variable possède :
///   - un identifiant unique (`id`) pour la référencer dans les widgets et la logique.
///   - un nom (`name`) lisible, qui peut être utilisé dans les expressions.
///   - un type (`type`) parmi les types supportés.
///   - une valeur initiale (`initialValue`) sous forme brute (type selon la variable).
///   - un indicateur (`persistent`) indiquant si la valeur doit persister entre les sessions.
///
/// Les types supportés sont définis par l'énumération [VariableType].
/// Pour l'instant, les types primitifs et les collections simples sont gérés.
///
/// La classe est immuable ; utilisez [copyWith] pour créer des copies modifiées.
class Variable {
  /// Identifiant unique de la variable.
  final String id;

  /// Nom lisible de la variable (ex: "compteur", "pseudo").
  final String name;

  /// Type de la variable.
  final VariableType type;

  /// Valeur initiale de la variable.
  /// Le type Dart dépend de [type] :
  ///   - `int` -> `int`
  ///   - `double` -> `double`
  ///   - `bool` -> `bool`
  ///   - `String` -> `String`
  ///   - `List` -> `List<dynamic>`
  ///   - `Map` -> `Map<String, dynamic>`
  ///   - `Object` -> tout type (ou null)
  /// Peut être null si non défini.
  final dynamic initialValue;

  /// Indique si la variable doit persister entre les exécutions (stockage local).
  final bool persistent;

  /// Constructeur principal.
  const Variable({
    required this.id,
    required this.name,
    required this.type,
    this.initialValue,
    this.persistent = false,
  });

  /// Crée une nouvelle variable avec un identifiant généré automatiquement.
  ///
  /// [name] : nom de la variable (obligatoire).
  /// [type] : type de la variable (défaut [VariableType.string]).
  /// [initialValue] : valeur initiale (doit être cohérente avec le type).
  /// [persistent] : persistance éventuelle.
  factory Variable.create({
    required String name,
    VariableType type = VariableType.string,
    dynamic initialValue,
    bool persistent = false,
  }) {
    if (name.trim().isEmpty) {
      throw ValidationError.missingField('name');
    }
    return Variable(
      id: UuidGenerator.generateVariableId(),
      name: name.trim(),
      type: type,
      initialValue: initialValue,
      persistent: persistent,
    );
  }

  /// Crée une instance à partir d'une map JSON.
  ///
  /// [json] : la map contenant les données de la variable.
  /// Lève une [ValidationError] si des champs obligatoires sont manquants ou invalides.
  factory Variable.fromJson(Map<String, dynamic> json) {
    // Identifiant
    final String? id = JsonUtils.getString(json, 'id');
    if (id == null || id.isEmpty) {
      throw ValidationError.missingField('id', path: 'variable');
    }

    // Nom
    final String? name = JsonUtils.getString(json, 'name');
    if (name == null || name.trim().isEmpty) {
      throw ValidationError.missingField('name', path: 'variable.$id');
    }

    // Type
    final String? typeStr = JsonUtils.getString(json, 'type');
    if (typeStr == null) {
      throw ValidationError.missingField('type', path: 'variable.$id');
    }
    final VariableType type = VariableType.fromString(typeStr);

    // Valeur initiale
    final dynamic initialValue = json['initial_value'];

    // Persistance
    final bool persistent = JsonUtils.getBool(json, 'persistent') ?? false;

    return Variable(
      id: id,
      name: name.trim(),
      type: type,
      initialValue: initialValue,
      persistent: persistent,
    );
  }

  /// Convertit la variable en map JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name, // ex: "int", "string", etc.
      if (initialValue != null) 'initial_value': initialValue,
      if (persistent) 'persistent': persistent,
    };
  }

  /// Crée une copie de la variable en remplaçant certains champs.
  Variable copyWith({
    String? id,
    String? name,
    VariableType? type,
    dynamic initialValue,
    bool? persistent,
  }) {
    return Variable(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      initialValue: initialValue ?? this.initialValue,
      persistent: persistent ?? this.persistent,
    );
  }

  /// Vérifie si la valeur initiale est cohérente avec le type déclaré.
  /// Retourne `true` si la valeur est valide ou null, sinon `false`.
  bool isInitialValueValid() {
    if (initialValue == null) return true;
    switch (type) {
      case VariableType.int:
        return initialValue is int || initialValue is double || initialValue is String;
      case VariableType.double:
        return initialValue is double || initialValue is int || initialValue is String;
      case VariableType.bool:
        return initialValue is bool || initialValue is String;
      case VariableType.string:
        return initialValue is String;
      case VariableType.list:
        return initialValue is List;
      case VariableType.map:
        return initialValue is Map;
      case VariableType.object:
        return true; // tout type est accepté
    }
  }

  @override
  String toString() => 'Variable(id: $id, name: $name, type: ${type.name})';
}

/// Enumération des types de variables supportés.
enum VariableType {
  int,
  double,
  bool,
  string,
  list,
  map,
  object;

  /// Convertit une chaîne en [VariableType].
  /// Accepte les valeurs : "int", "double", "bool", "string", "list", "map", "object".
  /// Lève une [ArgumentError] si la chaîne ne correspond à aucun type.
  static VariableType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'int':
        return VariableType.int;
      case 'double':
        return VariableType.double;
      case 'bool':
        return VariableType.bool;
      case 'string':
        return VariableType.string;
      case 'list':
        return VariableType.list;
      case 'map':
        return VariableType.map;
      case 'object':
        return VariableType.object;
      default:
        throw ArgumentError('Type de variable inconnu : $value');
    }
  }

  /// Convertit le type en chaîne lisible pour l'affichage.
  String get displayName {
    switch (this) {
      case VariableType.int:
        return 'Entier';
      case VariableType.double:
        return 'Nombre décimal';
      case VariableType.bool:
        return 'Booléen';
      case VariableType.string:
        return 'Texte';
      case VariableType.list:
        return 'Liste';
      case VariableType.map:
        return 'Dictionnaire';
      case VariableType.object:
        return 'Objet';
    }
  }
}