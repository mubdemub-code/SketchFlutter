import '../../models/logic_block.dart';

/// Générateur de code pour le bloc `if` (condition).
///
/// Génère une structure if/else basée sur les paramètres :
///   - `condition` : map décrivant left, operator, right
///   - `then_blocks` : liste de blocs à exécuter si condition vraie
///   - `else_blocks` : liste de blocs à exécuter si condition fausse
class IfGenerator {
  /// Génère le code Dart pour le bloc.
  static String generate(LogicBlock block, {String indent = ''}) {
    final condition = block.getParameter('condition');
    final thenBlocks = block.getListParameter('then_blocks') ?? [];
    final elseBlocks = block.getListParameter('else_blocks') ?? [];

    final conditionCode = _conditionToCode(condition);
    if (conditionCode == null) {
      return '$indent// if : condition invalide';
    }

    final buffer = StringBuffer();
    buffer.writeln('$indent if ($conditionCode) {');
    // Générer les blocs du then
    for (final child in thenBlocks) {
      if (child is Map<String, dynamic>) {
        final childBlock = LogicBlock.fromJson(child);
        // On appelle la génération du bloc via un dispatcher (méthode statique de la classe utilitaire)
        // Pour éviter la circularité, on utilise la méthode statique de CodeBlockGenerator définie plus bas.
        buffer.writeln(CodeBlockGenerator.generate(childBlock, indent: indent + '  '));
      }
    }
    if (elseBlocks.isNotEmpty) {
      buffer.writeln('$indent } else {');
      for (final child in elseBlocks) {
        if (child is Map<String, dynamic>) {
          final childBlock = LogicBlock.fromJson(child);
          buffer.writeln(CodeBlockGenerator.generate(childBlock, indent: indent + '  '));
        }
      }
      buffer.writeln('$indent }');
    } else {
      buffer.writeln('$indent }');
    }
    return buffer.toString();
  }

  /// Convertit une condition (map) en code Dart.
  static String? _conditionToCode(dynamic condition) {
    if (condition is! Map) return null;
    final left = condition['left'];
    final operator = condition['operator']?.toString();
    final right = condition['right'];

    if (left is Map && right is Map) {
      final leftCode = _operandToCode(left);
      final rightCode = _operandToCode(right);
      if (leftCode != null && rightCode != null && operator != null) {
        return '$leftCode $operator $rightCode';
      }
    }
    return null;
  }

  /// Convertit un opérande (variable ou littéral) en code.
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
    if (value is bool) return value ? 'true' : 'false';
    if (value is num) return value.toString();
    if (value is String) return "'${value.replaceAll("'", "\\'")}'";
    return value.toString();
  }
}