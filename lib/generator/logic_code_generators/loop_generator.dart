import '../../models/logic_block.dart';

/// Générateur de code pour le bloc `loop` (boucle for).
///
/// Paramètres attendus :
///   - `iterations` : nombre d'itérations (int)
///   - `body` : liste de blocs à exécuter à chaque itération
class LoopGenerator {
  /// Génère le code Dart pour le bloc.
  static String generate(LogicBlock block, {String indent = ''}) {
    final iterations = block.getIntParameter('iterations') ?? 0;
    final body = block.getListParameter('body') ?? [];

    if (iterations <= 0) {
      return '$indent// loop : iterations invalide';
    }

    final buffer = StringBuffer();
    buffer.writeln('$indent for (int i = 0; i < $iterations; i++) {');
    for (final child in body) {
      if (child is Map<String, dynamic>) {
        final childBlock = LogicBlock.fromJson(child);
        buffer.writeln(CodeBlockGenerator.generate(childBlock, indent: indent + '  '));
      }
    }
    buffer.writeln('$indent }');
    return buffer.toString();
  }
}