import '../../models/logic_block.dart';

/// Générateur de code pour le bloc `math_operation`.
///
/// Ce bloc effectue une opération mathématique et affecte le résultat
/// à une variable. Paramètres :
///   - `result_variable_id` : variable de destination
///   - `left` / `right` : opérandes
///   - `operator` : opérateur arithmétique (+, -, *, /)
class MathOperationGenerator {
  static String generate(LogicBlock block, {String indent = ''}) {
    final resultVar = block.getStringParameter('result_variable_id') ?? '';
    final left = block.getParameter('left');
    final right = block.getParameter('right');
    final operator = block.getStringParameter('operator') ?? '+';

    if (resultVar.isEmpty || left == null || right == null) {
      return '$indent// math_operation : paramètres manquants';
    }

    final leftCode = _operandToCode(left);
    final rightCode = _operandToCode(right);
    if (leftCode == null || rightCode == null) {
      return '$indent// math_operation : opérandes invalides';
    }

    return "$indent AppState.instance.set_$resultVar($leftCode $operator $rightCode);";
  }

  static String? _operandToCode(dynamic operand) {
    if (operand is Map) {
      final type = operand['type']?.toString();
      if (type == 'variable') {
        final varId = operand['id']?.toString();
        if (varId != null) return 'AppState.instance.$varId';
      } else if (type == 'literal') {
        return _literalToCode(operand['value']);
      }
    }
    return null;
  }

  static String _literalToCode(dynamic value) {
    if (value == null) return 'null';
    if (value is num) return value.toString();
    if (value is bool) return value ? 'true' : 'false';
    if (value is String) return "'${value.replaceAll("'", "\\'")}'";
    return value.toString();
  }
}