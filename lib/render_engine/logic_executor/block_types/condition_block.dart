import '../../../models/logic_block.dart';
import '../logic_executor.dart';

/// Exécuteur pour le bloc `if` (condition).
///
/// Paramètres attendus :
///   - `condition` : map { left, operator, right }
///   - `then_blocks` : liste de blocs à exécuter si la condition est vraie
///   - `else_blocks` : liste de blocs à exécuter si la condition est fausse
///
/// L'évaluation se base sur les valeurs actuelles des variables accessibles
/// via le `RenderContext` de l'exécuteur.
class ConditionBlock {
  static void execute(LogicBlock block, LogicExecutor executor) {
    final condition = block.getParameter('condition');
    final thenBlocks = block.getListParameter('then_blocks') ?? [];
    final elseBlocks = block.getListParameter('else_blocks') ?? [];

    if (_evaluateCondition(condition, executor)) {
      for (final child in thenBlocks) {
        if (child is Map<String, dynamic>) {
          final childBlock = LogicBlock.fromJson(child);
          executor.executeBlock(childBlock);
        }
      }
    } else {
      for (final child in elseBlocks) {
        if (child is Map<String, dynamic>) {
          final childBlock = LogicBlock.fromJson(child);
          executor.executeBlock(childBlock);
        }
      }
    }
  }

  /// Évalue la condition et retourne un booléen.
  static bool _evaluateCondition(dynamic condition, LogicExecutor executor) {
    if (condition is! Map) return false;
    final left = condition['left'];
    final operator = condition['operator']?.toString();
    final right = condition['right'];

    final leftValue = _evaluateOperand(left, executor);
    final rightValue = _evaluateOperand(right, executor);

    if (leftValue == null || rightValue == null || operator == null) return false;

    switch (operator) {
      case '==':
        return leftValue == rightValue;
      case '!=':
        return leftValue != rightValue;
      case '>':
        return _compare(leftValue, rightValue) > 0;
      case '<':
        return _compare(leftValue, rightValue) < 0;
      case '>=':
        return _compare(leftValue, rightValue) >= 0;
      case '<=':
        return _compare(leftValue, rightValue) <= 0;
      default:
        return false;
    }
  }

  /// Évalue un opérande (variable ou littéral).
  static dynamic _evaluateOperand(dynamic operand, LogicExecutor executor) {
    if (operand is Map) {
      final type = operand['type']?.toString();
      if (type == 'variable') {
        final varId = operand['id']?.toString();
        if (varId != null) {
          return executor.renderContext.resolver.variables[varId];
        }
      } else if (type == 'literal') {
        return operand['value'];
      }
    }
    return null;
  }

  /// Compare deux valeurs (numériques ou chaînes).
  static int _compare(dynamic a, dynamic b) {
    if (a is num && b is num) {
      return a.compareTo(b);
    } else if (a is String && b is String) {
      return a.compareTo(b);
    } else {
      return a.toString().compareTo(b.toString());
    }
  }
}