import '../core/errors/validation_error.dart';
import '../core/utils/json_utils.dart';
import '../core/utils/uuid_generator.dart';

/// Représentation d'un bloc logique dans SketchFlutter.
///
/// Un bloc logique est une instruction ou une structure de contrôle
/// (condition, boucle, affectation, affichage, navigation...).
/// Il est stocké en JSON sous la forme d'un objet contenant au minimum un champ `type`.
/// Les autres champs sont des paramètres spécifiques au type de bloc.
///
/// Exemple de bloc `set_variable` :
/// ```json
/// {
///   "type": "set_variable",
///   "variable_id": "var_1",
///   "value": { "type": "literal", "value": 5 }
/// }
/// ```
///
/// La classe est immuable et fournit des méthodes de manipulation et de validation.
/// Les blocs peuvent être imbriqués (ex: `then_blocks`, `else_blocks`) ; ces listes
/// sont conservées telles quelles sous forme de listes de maps dans [parameters].
class LogicBlock {
  /// Identifiant unique du bloc (optionnel, généré si absent).
  final String? id;

  /// Type du bloc (ex: "set_variable", "show_snackbar", "if", "loop", etc.).
  final String type;

  /// Paramètres supplémentaires du bloc (tous les champs sauf `type` et `id`).
  /// Peut être `null` si le bloc n'a pas de paramètres.
  final Map<String, dynamic>? parameters;

  /// Constructeur principal.
  const LogicBlock({
    this.id,
    required this.type,
    this.parameters,
  });

  /// Crée un nouveau bloc avec un identifiant généré automatiquement.
  ///
  /// [type] : type du bloc.
  /// [parameters] : paramètres spécifiques (optionnel).
  factory LogicBlock.create({
    required String type,
    Map<String, dynamic>? parameters,
  }) {
    if (type.trim().isEmpty) {
      throw ValidationError.missingField('type');
    }
    return LogicBlock(
      id: UuidGenerator.generateBlockId(),
      type: type.trim(),
      parameters: parameters,
    );
  }

  /// Crée une instance à partir d'une map JSON.
  ///
  /// [json] : la map contenant les données du bloc.
  /// Lève une [ValidationError] si le champ `type` est manquant ou vide.
  factory LogicBlock.fromJson(Map<String, dynamic> json) {
    final String? type = JsonUtils.getString(json, 'type');
    if (type == null || type.trim().isEmpty) {
      throw ValidationError.missingField('type', path: 'logic_block');
    }

    final String? id = JsonUtils.getString(json, 'id');

    // CORRECTION : Extraction des paramètres de façon 100% null-safe sans opérateur cascade ambigu.
    Map<String, dynamic>? extractedParameters;
    if (json.isNotEmpty) {
      extractedParameters = Map<String, dynamic>.from(json);
      extractedParameters.remove('type');
      extractedParameters.remove('id');
    }

    return LogicBlock(
      id: id,
      type: type.trim(),
      parameters: extractedParameters != null && extractedParameters.isNotEmpty 
          ? extractedParameters 
          : null,
    );
  }

  /// Convertit le bloc en map JSON.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'type': type,
      if (parameters != null) ...parameters!,
    };
  }

  /// Crée une copie du bloc en remplaçant certains champs.
  LogicBlock copyWith({
    String? id,
    String? type,
    Map<String, dynamic>? parameters,
  }) {
    return LogicBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      parameters: parameters ?? this.parameters,
    );
  }

  /// Retourne une copie profonde du bloc (les paramètres sont copiés récursivement).
  LogicBlock deepCopy() {
    return LogicBlock(
      id: id,
      type: type,
      parameters: parameters != null
          ? _deepCopyMap(parameters!)
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers de typage rapide
  // ---------------------------------------------------------------------------

  /// Vérifie si ce bloc est une condition (if).
  bool get isIf => type == 'if' || type == 'condition';

  /// Vérifie si ce bloc est une boucle.
  bool get isLoop => type == 'loop' || type == 'for' || type == 'while';

  /// Vérifie si ce bloc est une affectation de variable.
  bool get isSetVariable => type == 'set_variable';

  /// Vérifie si ce bloc affiche un message (snackbar).
  bool get isShowSnackbar => type == 'show_snackbar';

  /// Vérifie si ce bloc navigue vers une autre page.
  bool get isNavigate => type == 'navigate_to' || type == 'navigate';

  /// Vérifie si ce bloc est un appel à une API.
  bool get isCallApi => type == 'call_api';

  /// Vérifie si ce bloc est une opération mathématique.
  bool get isMathOperation => type == 'math_operation';

  /// Récupère un paramètre typé.
  ///
  /// [key] : clé du paramètre.
  /// Retourne la valeur ou `null` si absente.
  dynamic getParameter(String key) {
    if (parameters == null) return null;
    return parameters![key];
  }

  /// Récupère un paramètre de type bool.
  bool? getBoolParameter(String key) {
    final value = getParameter(key);
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return null;
  }

  /// Récupère un paramètre de type int.
  int? getIntParameter(String key) {
    final value = getParameter(key);
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Récupère un paramètre de type double.
  double? getDoubleParameter(String key) {
    final value = getParameter(key);
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Récupère un paramètre de type String.
  String? getStringParameter(String key) {
    final value = getParameter(key);
    if (value is String) return value;
    return value?.toString();
  }

  /// Récupère un paramètre de type liste de blocs (par exemple `then_blocks`).
  /// Convertit les maps en [LogicBlock] si possible, sinon les laisse brutes.
  List<dynamic>? getListParameter(String key) {
    final value = getParameter(key);
    if (value is List) return value;
    return null;
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  /// Vérifie si le bloc est valide (type non vide).
  bool isValid() {
    return type.trim().isNotEmpty;
  }

  @override
  String toString() => 'LogicBlock(type: $type, id: $id)';

  // ---------------------------------------------------------------------------
  // Helpers privés
  // ---------------------------------------------------------------------------

  /// Copie profonde d'une map (en particulier les listes de maps imbriquées).
  static Map<String, dynamic> _deepCopyMap(Map<String, dynamic> source) {
    final Map<String, dynamic> result = {};
    source.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        result[key] = _deepCopyMap(value);
      } else if (value is List) {
        result[key] = _deepCopyList(value);
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  /// Copie profonde d'une liste (en gérant les maps et listes imbriquées).
  static List<dynamic> _deepCopyList(List<dynamic> source) {
    return source.map((item) {
      if (item is Map<String, dynamic>) {
        return _deepCopyMap(item);
      } else if (item is List) {
        return _deepCopyList(item);
      } else {
        return item;
      }
    }).toList();
  }
}

/// Classe de constantes pour les types de blocs couramment utilisés.
/// Facilite la création de blocs sans se tromper de nom.
class LogicBlockTypes {
  LogicBlockTypes._();

  static const String setVariable = 'set_variable';
  static const String showSnackbar = 'show_snackbar';
  static const String navigateTo = 'navigate_to';
  static const String ifBlock = 'if';
  static const String loopBlock = 'loop';
  static const String callApi = 'call_api';
  static const String mathOperation = 'math_operation';
  static const String updateWidgetProperty = 'update_widget_property';
}
