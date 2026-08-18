import '../../models/logic_block.dart';

/// Générateur de code pour le bloc `show_snackbar`.
///
/// Affiche un SnackBar avec un message.
class ShowSnackbarGenerator {
  /// Génère le code Dart pour le bloc.
  static String generate(LogicBlock block, {String indent = ''}) {
    final message = block.getStringParameter('message') ?? '';
    // Échappement du message pour éviter de casser le code.
    final escaped = message.replaceAll("'", "\\'").replaceAll('\n', '\\n');
    return "$indent ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$escaped')));";
  }
}