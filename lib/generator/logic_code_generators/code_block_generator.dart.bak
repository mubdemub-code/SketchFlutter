import '../../models/logic_block.dart';
import 'set_variable_generator.dart';
import 'show_snackbar_generator.dart';
import 'navigate_generator.dart';
import 'if_generator.dart';
import 'loop_generator.dart';
import 'math_operation_generator.dart';

/// Dispatcher central pour la génération de code des blocs logiques.
///
/// Cette classe fournit une méthode statique [generate] qui prend un
/// [LogicBlock] et retourne le code Dart correspondant, en appelant
/// le générateur approprié selon le type de bloc.
class CodeBlockGenerator {
  /// Génère le code Dart pour un bloc.
  ///
  /// [block] : le bloc logique.
  /// [indent] : indentation à appliquer.
  /// [pageClassName] : nom de la classe de page pour la navigation (optionnel).
  static String generate(LogicBlock block, {String indent = '', String? pageClassName}) {
    switch (block.type) {
      case LogicBlockTypes.setVariable:
        return SetVariableGenerator.generate(block, indent: indent);
      case LogicBlockTypes.showSnackbar:
        return ShowSnackbarGenerator.generate(block, indent: indent);
      case LogicBlockTypes.navigateTo:
        return NavigateGenerator.generate(block, indent: indent, pageClassName: pageClassName);
      case LogicBlockTypes.ifBlock:
        return IfGenerator.generate(block, indent: indent);
      case LogicBlockTypes.loopBlock:
        return LoopGenerator.generate(block, indent: indent);
      case LogicBlockTypes.mathOperation:
        return MathOperationGenerator.generate(block, indent: indent);
      default:
        return '$indent// Bloc non supporté: ${block.type}';
    }
  }
}