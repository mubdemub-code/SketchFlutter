import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../models/page_model.dart';
import '../models/project_model.dart';
import '../models/widget_node.dart';
import '../providers/editor_provider.dart';
import '../providers/project_provider.dart';
import '../render_engine/json_widget_parser.dart';
import '../widgets/canvas_area.dart';
import '../widgets/property_inspector.dart';
import '../widgets/widget_palette.dart';

/// Onglet Design de l'éditeur.
///
/// Organise l'espace de conception visuelle :
///   - Au centre : la toile interactive (zoom / pan) qui affiche l'aperçu
///     en temps réel du widget racine de la page courante.
///   - En bas : la palette de widgets pour ajouter de nouveaux éléments.
///   - Lorsqu'un widget est sélectionné, un panneau d'inspection apparaît
///     en bas (ou en overlay) pour modifier ses propriétés.
///
/// La sélection est gérée par [editorProvider] et le projet actif est lu
/// depuis [activeProjectProvider]. Les modifications sont immédiatement
/// répercutées sur le projet et l'aperçu se met à jour.
class DesignTab extends ConsumerWidget {
  /// Projet actif (non null, fourni par l'éditeur).
  final ProjectModel project;

  const DesignTab({super.key, required this.project});

  /// Ajoute un nouveau widget de type [type] à la page courante.
  ///
  /// Si un widget est sélectionné ([selectedWidgetId] non null) et qu'il
  /// peut accueillir des enfants, le nouveau widget sera ajouté comme enfant
  /// de celui-ci. Sinon, il est ajouté à la racine de la page (ou dans le
  /// body du Scaffold si la racine est un Scaffold).
  void _addWidgetToPage(
    BuildContext context,
    WidgetRef ref,
    String type,
    PageModel? currentPage,
    WidgetNode? rootWidget,
    String? selectedWidgetId,
  ) {
    if (currentPage == null) return;

    final editorNotifier = ref.read(editorProvider.notifier);

    // Créer un nouveau widget avec des propriétés par défaut.
    final newWidget = _createDefaultWidget(type);
    if (newWidget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Type de widget non supporté : $type')),
      );
      return;
    }

    // Si un widget est sélectionné et qu'il accepte des enfants, on l'utilise
    // comme parent ; sinon on ajoute à la racine.
    String? parentId;
    if (selectedWidgetId != null && rootWidget != null) {
      final selected = rootWidget.findById(selectedWidgetId);
      if (selected != null &&
          (selected.type == 'Column' ||
              selected.type == 'Row' ||
              selected.type == 'Container' ||
              selected.type == 'Scaffold')) {
        parentId = selectedWidgetId;
      }
    }

    // Ajouter le widget.
    editorNotifier.addWidget(newWidget, parentId: parentId);
  }

  /// Crée un [WidgetNode] avec des propriétés par défaut selon le type.
  WidgetNode? _createDefaultWidget(String type) {
    switch (type) {
      case 'Container':
        return WidgetNode.create(
          type: 'Container',
          properties: {'color': '#FFFFFFFF'},
        );
      case 'Text':
        return WidgetNode.create(
          type: 'Text',
          properties: {'data': 'Nouveau texte', 'fontSize': 16},
        );
      case 'Row':
        return WidgetNode.create(type: 'Row');
      case 'Column':
        return WidgetNode.create(type: 'Column');
      case 'Button':
        return WidgetNode.create(
          type: 'Button',
          properties: {'text': 'Bouton', 'buttonType': 'elevated'},
        );
      case 'Image':
        return WidgetNode.create(
          type: 'Image',
          properties: {'src': ''},
        );
      case 'Icon':
        return WidgetNode.create(
          type: 'Icon',
          properties: {'icon': 'star', 'size': 24},
        );
      case 'TextField':
        return WidgetNode.create(
          type: 'TextField',
          properties: {'hintText': 'Saisir...'},
        );
      case 'Checkbox':
        return WidgetNode.create(
          type: 'Checkbox',
          properties: {'value': false},
        );
      case 'Switch':
        return WidgetNode.create(
          type: 'Switch',
          properties: {'value': false},
        );
      case 'Slider':
        return WidgetNode.create(
          type: 'Slider',
          properties: {'min': 0, 'max': 100, 'value': 50},
        );
      case 'ListView':
        return WidgetNode.create(type: 'ListView', children: []);
      case 'GridView':
        return WidgetNode.create(type: 'GridView', children: []);
      case 'ListTile':
        return WidgetNode.create(
          type: 'ListTile',
          properties: {'title': 'Titre', 'subtitle': 'Sous-titre'},
        );
      case 'Scaffold':
        return WidgetNode.create(type: 'Scaffold');
      case 'AppBar':
        return WidgetNode.create(
          type: 'AppBar',
          properties: {'title': 'Titre'},
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorProvider);
    final currentPageId = editorState.currentPageId;
    final selectedWidgetId = editorState.selectedWidgetId;

    // Récupérer la page courante.
    PageModel? currentPage;
    for (final page in project.pages) {
      if (page.id == currentPageId) {
        currentPage = page;
        break;
      }
    }
    // Si la page n'existe plus, prendre la première page disponible.
    if (currentPage == null && project.pages.isNotEmpty) {
      currentPage = project.pages.first;
    }

    // Si aucune page n'existe, afficher un message.
    if (currentPage == null) {
      return Center(
        child: Text(
          'Aucune page. Ajoutez une page dans l\'onglet Pages.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final rootWidget = currentPage.rootWidget;

    // Trouver le widget sélectionné.
    WidgetNode? selectedWidget;
    if (selectedWidgetId != null && rootWidget != null) {
      selectedWidget = rootWidget.findById(selectedWidgetId);
    }

    // Construire l'aperçu à l'aide du parseur.
    final parser = JsonWidgetParser(context: context);
    Widget previewWidget;
    if (rootWidget != null) {
      previewWidget = parser.buildWidget(rootWidget, context);
    } else {
      previewWidget = const SizedBox.shrink();
    }

    return Column(
      children: [
        // Zone de rendu (toile).
        Expanded(
          child: CanvasArea(
            child: previewWidget,
            onBackgroundTap: () {
              // Désélectionner en tapant sur le fond.
              ref.read(editorProvider.notifier).clearSelection();
            },
          ),
        ),

        // Palette de widgets (en bas de la toile).
        WidgetPalette(
          onWidgetSelected: (type) {
            _addWidgetToPage(
              context,
              ref,
              type,
              currentPage,
              rootWidget,
              selectedWidgetId,
            );
          },
        ),

        // Inspecteur de propriétés (si un widget est sélectionné).
        if (selectedWidget != null)
          Container(
            height: 250,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.surface
                : Colors.grey.shade100,
            child: PropertyInspector(
              selectedWidget: selectedWidget,
              onPropertyChanged: (key, value) {
                ref
                    .read(editorProvider.notifier)
                    .updateWidgetProperty(selectedWidget!.id, key, value);
              },
              onDelete: () {
                ref
                    .read(editorProvider.notifier)
                    .removeWidget(selectedWidget!.id);
              },
              onDuplicate: () {
                // TODO: Implémenter la duplication du widget sélectionné.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Duplication à venir')),
                );
              },
            ),
          ),
      ],
    );
  }
}
