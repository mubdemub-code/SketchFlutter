import '../../models/logic_block.dart';

/// Générateur de code pour le bloc `navigate_to`.
///
/// Navigue vers une autre page en utilisant `Navigator.push`.
class NavigateGenerator {
  /// Génère le code Dart pour le bloc.
  static String generate(LogicBlock block, {String indent = '', String? pageClassName}) {
    final pageId = block.getStringParameter('page_id') ?? '';
    if (pageId.isEmpty) {
      return '$indent// navigate_to : page_id manquant';
    }
    // On suppose que pageClassName est passé par l'appelant (par exemple 'HomePage').
    // Sinon, on construit un nom basique.
    final className = pageClassName ?? _pageIdToClassName(pageId);
    return "$indent Navigator.push(context, MaterialPageRoute(builder: (_) => $className()));";
  }

  /// Convertit un ID de page en nom de classe PascalCase.
  static String _pageIdToClassName(String pageId) {
    final words = pageId
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .toList();
    return '${words.join()}Page';
  }
}