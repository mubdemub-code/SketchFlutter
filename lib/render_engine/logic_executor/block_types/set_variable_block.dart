import '../../../models/logic_block.dart';
import '../../render_context.dart';

/// Exécuteur pour le bloc `set_variable`.
///
/// Met à jour une variable globale via le callback `setVariable` du
/// [RenderContext]. La valeur peut être un littéral ou une référence
/// à une autre variable.
class SetVariableBlock {
  static void execute(LogicBlock block, RenderContext context) {
    final variableId = block.getStringParameter('variable_id') ?? '';
    final value = block.getParameter('value');

    if (variableId.isEmpty) return;

    // Résoudre la valeur si c'est une référence à une autre variable.
    dynamic resolvedValue = context.resolver.resolveVariableValue(value);

    // Mettre à jour la variable via le callback.
    context.setVariable?.call(variableId, resolvedValue);
  }
}