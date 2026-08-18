import 'package:flutter/material.dart';

import '../../../models/logic_block.dart';
import '../../../models/project_model.dart';

/// Exécuteur pour le bloc `navigate_to`.
///
/// Tente d'utiliser le callback [onNavigate] fourni par l'écran parent.
/// Si ce callback est `null` (par exemple hors aperçu), un SnackBar est
/// affiché à la place.
class NavigateBlock {
  static void execute(
    LogicBlock block,
    ProjectModel project,
    BuildContext context, {
    void Function(String pageId)? onNavigate,
  }) {
    final pageId = block.getStringParameter('page_id') ?? '';
    if (pageId.isEmpty) return;

    if (onNavigate != null) {
      // Déléguer la navigation à l'écran parent (pile de pages)
      onNavigate(pageId);
    } else {
      // Fallback : afficher un SnackBar informatif
      final page = project.getPageById(pageId);
      final pageName = page?.name ?? pageId;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navigation vers $pageName')),
      );
    }
  }
}