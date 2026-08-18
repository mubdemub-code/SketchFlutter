import '../../models/logic_block.dart';

/// Générateur de code pour le bloc `set_variable`.
///
/// Ce bloc définit la valeur d'une variable globale via `AppState.instance`.
/// Le paramètre `variable_id` désigne la variable à modifier et `value`
/// peut être un littéral ou une référence à une autre variable.
class SetVariableGenerator {
  /// Génère le code Dart pour le bloc.
  ///
  /// [block] : le bloc logique.
  /// [indent] : indentation à appliquer au code généré.
  static String generate(LogicBlock block, {String indent = ''}) {
    final variableId = block.getStringParameter('variable_id') ?? '';
    final value = block.getParameter('value');

    String valueCode;
    if (value is String && value.startsWith('@variables.')) {
      // Référence à une autre variable : on utilise sa valeur actuelle.
      valueCode = value.substring('@variables.'.length);
    } else {
      // Littéral, on convertit avec la logique de conversion de base.
      valueCode = _literalToCode(value);
    }

    if (variableId.isEmpty) {
      return '$indent// set_variable : variable_id manquant';
    }

    return "$indent AppState.instance.set_$variableId($valueCode);";
  }

  /// Convertit une valeur littérale en code Dart.
  static String _literalToCode(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return value ? 'true' : 'false';
    if (value is num) return value.toString();
    if (value is String) {
      // Si la chaîne est numérique et que la variable cible est int/double, on ne force pas le type ici.
      // On suppose que la valeur est déjà correcte.
      return "'${value.replaceAll("'", "\\'")}'";
    }
    return value.toString();
  }
}