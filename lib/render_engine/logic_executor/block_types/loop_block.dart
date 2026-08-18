import '../../../models/logic_block.dart';
import '../logic_executor.dart';

/// Exécuteur pour le bloc `loop` (boucle).
///
/// Paramètres attendus :
///   - `iterations` : nombre d'itérations (int).
///   - `body` : liste de blocs à exécuter à chaque itération.
///
/// L'exécuteur utilise le [LogicExecutor] parent pour exécuter les blocs
/// enfants de manière récursive.
class LoopBlock {
  static void execute(LogicBlock block, LogicExecutor executor) {
    final iterations = block.getIntParameter('iterations') ?? 0;
    final body = block.getListParameter('body') ?? [];

    if (iterations <= 0) return;

    for (int i = 0; i < iterations; i++) {
      for (final child in body) {
        if (child is Map<String, dynamic>) {
          final childBlock = LogicBlock.fromJson(child);
          executor.executeBlock(childBlock);
        }
      }
    }
  }
}