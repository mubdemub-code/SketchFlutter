import '../../../models/logic_block.dart';
import '../logic_executor.dart';

/// Exécuteur pour le bloc `math_operation`.
///
/// Paramètres attendus :
///   - `result_variable_id` : identifiant de la variable qui recevra le résultat.
///   - `left` : opérande gauche (Map { type: 'variable' | 'literal', ... }).
///   - `right` : opérande droit (Map).
///   - `operator` : opérateur arithmétique (`+`, `-`, `*`, `/`).
///
/// Le résultat est affecté à la variable via la méthode [LogicExecutor.renderContext.setVariable].
class MathOperationBlock {
  static void execute(LogicBlock block, LogicExecutor executor) {
    final resultVarId = block.getStringParameter('result_variable_id') ?? '';
    final left = block.getParameter('left');
    final right = block.getParameter('right');
    final operator = block.getStringParameter('operator') ?? '+';

    if (resultVarId.isEmpty || left == null || right == null) return;

    final leftValue = _evaluateOperand(left, executor);
    final rightValue = _evaluateOperand(right, executor);

    if (leftValue is! num || rightValue is! num) return;

    num result;
    switch (operator) {
      case '+':
        result = leftValue + rightValue;
        break;
      case '-':
        result = leftValue - rightValue;
        break;
      case '*':
        result = leftValue * rightValue;
        break;
      case '/':
        if (rightValue == 0) return;
        result = leftValue / rightValue;
        break;
      default:
        return;
    }

    // Mettre à jour la variable via le callback du RenderContext.
    executor.renderContext.setVariable?.call(resultVarId, result);
  }

  /// Évalue un opérande (variable ou littéral) et retourne une valeur numérique.
  static dynamic _evaluateOperand(dynamic operand, LogicExecutor executor) {
    if (operand is Map) {
      final type = operand['type']?.toString();
      if (type == 'variable') {
        final varId = operand['id']?.toString();
        if (varId != null) {
          return executor.renderContext.resolver.variables[varId];
        }
      } else if (type == 'literal') {
        final value = operand['value'];
        if (value is num) return value;
        if (value is String) {
          return num.tryParse(value);
        }
      }
    }
    return null;
  }
}