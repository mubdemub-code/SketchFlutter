import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../models/page_model.dart';
import '../models/project_model.dart';
import '../models/widget_node.dart';
import '../providers/editor_provider.dart';
import '../render_engine/json_widget_parser.dart';
import '../render_engine/render_context.dart';
import '../widgets/canvas_area.dart';
import '../widgets/property_inspector.dart';
import '../widgets/widget_palette.dart';

/// Onglet Design de l'éditeur.
///
/// Organise l'espace de conception visuelle :
///   - Au centre : la toile interactive qui affiche l'aperçu
///     du widget racine de la page courante.
///   - En bas : la palette de widgets.
///   - Lorsqu'un widget est sélectionné, un panneau d'inspection
///     apparaît pour modifier ses propriétés.
///
/// La sélection est gérée par [editorProvider].
class DesignTab extends ConsumerWidget {
  /// Projet actif.
  final ProjectModel project;

  const DesignTab({
    super.key,
    required this.project,
  });

  /// Ajoute un nouveau widget de type [type] à la page courante.
  ///
  /// Si un widget est sélectionné et qu'il peut accueillir des enfants,
  /// le nouveau widget est ajouté comme enfant.
  /// Sinon, il est ajouté à la racine de la page.
  void _addWidgetToPage(
    BuildContext context,
    WidgetRef ref,
    String type,
    PageModel? currentPage,
    WidgetNode? rootWidget,
    String? selectedWidgetId,
  ) {
    if (currentPage == null) {
      return;
    }

    final editorNotifier = ref.read(editorProvider.notifier);

    // Créer le widget demandé.
    final newWidget = _createDefaultWidget(type);

    if (newWidget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Type de widget non supporté : $type',
          ),
        ),
      );
      return;
    }

    // Déterminer le parent éventuel.
    String? parentId;

    if (selectedWidgetId != null && rootWidget != null) {
      final selected = rootWidget.findById(selectedWidgetId);

      if (selected != null &&
          (
            selected.type == 'Column' ||
            selected.type == 'Row' ||
            selected.type == 'Container' ||
            selected.type == 'Scaffold'
          )) {
        parentId = selectedWidgetId;
      }
    }

    // Ajouter le widget au projet.
    editorNotifier.addWidget(
      newWidget,
      parentId: parentId,
    );
  }

  /// Crée un [WidgetNode] avec des propriétés par défaut.
  WidgetNode? _createDefaultWidget(String type) {
    switch (type) {
      case 'Container':
        return WidgetNode.create(
          type: 'Container',
          properties: {
            'color': '#FFFFFFFF',
          },
        );

      case 'Text':
        return WidgetNode.create(
          type: 'Text',
          properties: {
            'data': 'Nouveau texte',
            'fontSize': 16,
          },
        );

      case 'Row':
        return WidgetNode.create(
          type: 'Row',
        );

      case 'Column':
        return WidgetNode.create(
          type: 'Column',
        );

      case 'Button':
        return WidgetNode.create(
          type: 'Button',
          properties: {
            'text': 'Bouton',
            'buttonType': 'elevated',
          },
        );

      case 'Image':
        return WidgetNode.create(
          type: 'Image',
          properties: {
            'src': '',
          },
        );

      case 'Icon':
        return WidgetNode.create(
          type: 'Icon',
          properties: {
            'icon': 'star',
            'size': 24,
          },
        );

      case 'TextField':
        return WidgetNode.create(
          type: 'TextField',
          properties: {
            'hintText': 'Saisir...',
          },
        );

      case 'Checkbox':
        return WidgetNode.create(
          type: 'Checkbox',
          properties: {
            'value': false,
          },
        );

      case 'Switch':
        return WidgetNode.create(
          type: 'Switch',
          properties: {
            'value': false,
          },
        );

      case 'Slider':
        return WidgetNode.create(
          type: 'Slider',
          properties: {
            'min': 0,
            'max': 100,
            'value': 50,
          },
        );

      case 'ListView':
        return WidgetNode.create(
          type: 'ListView',
          children: [],
        );

      case 'GridView':
        return WidgetNode.create(
          type: 'GridView',
          children: [],
        );

      case 'ListTile':
        return WidgetNode.create(
          type: 'ListTile',
          properties: {
            'title': 'Titre',
            'subtitle': 'Sous-titre',
          },
        );

      case 'Scaffold':
        return WidgetNode.create(
          type: 'Scaffold',
        );

      case 'AppBar':
        return WidgetNode.create(
          type: 'AppBar',
          properties: {
            'title': 'Titre',
          },
        );

      case 'SizedBox':
        return WidgetNode.create(
          type: 'SizedBox',
        );

      case 'Padding':
        return WidgetNode.create(
          type: 'Padding',
        );

      case 'Center':
        return WidgetNode.create(
          type: 'Center',
        );

      default:
        return null;
    }
  }

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final editorState = ref.watch(editorProvider);

    final currentPageId = editorState.currentPageId;
    final selectedWidgetId = editorState.selectedWidgetId;

    // ------------------------------------------------------------
    // Recherche de la page courante
    // ------------------------------------------------------------

    PageModel? currentPage;

    for (final page in project.pages) {
      if (page.id == currentPageId) {
        currentPage = page;
        break;
      }
    }

    // Si la page courante n'existe plus, utiliser la première page.
    if (currentPage == null && project.pages.isNotEmpty) {
      currentPage = project.pages.first;
    }

    // Aucune page disponible.
    if (currentPage == null) {
      return Center(
        child: Text(
          'Aucune page. Ajoutez une page dans l\'onglet Pages.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    // ------------------------------------------------------------
    // Widget racine
    // ------------------------------------------------------------

    final rootWidget = currentPage.rootWidget;

    // ------------------------------------------------------------
    // Widget sélectionné
    // ------------------------------------------------------------

    WidgetNode? selectedWidget;

    if (selectedWidgetId != null && rootWidget != null) {
      selectedWidget = rootWidget.findById(
        selectedWidgetId,
      );
    }

    // ------------------------------------------------------------
    // CONTEXTE DU MOTEUR DE RENDU
    //
    // IMPORTANT :
    // RenderContext actuel ne possède PAS :
    //   buildContext
    //   theme
    //
    // Il exige :
    //   project
    //   variables
    // ------------------------------------------------------------

    final renderContext = RenderContext(
      project: project,
      variables: const <String, dynamic>{},
    );

    // ------------------------------------------------------------
    // PARSEUR JSON -> FLUTTER
    //
    // JsonWidgetParser actuel possède :
    //   build(WidgetNode node)
    //
    // Il ne possède PAS :
    //   parse(...)
    // ------------------------------------------------------------

    final parser = JsonWidgetParser(
      context: renderContext,
    );

    // ------------------------------------------------------------
    // Construction de l'aperçu
    // ------------------------------------------------------------

    Widget previewWidget;

    if (rootWidget != null) {
      try {
        previewWidget = parser.build(
          rootWidget,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'Erreur lors du rendu du widget racine : $error',
        );

        debugPrintStack(
          stackTrace: stackTrace,
        );

        previewWidget = Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.errorContainer,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Erreur de rendu',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
    } else {
      previewWidget = const SizedBox.shrink();
    }

    // ------------------------------------------------------------
    // INTERFACE
    // ------------------------------------------------------------

    return Column(
      children: [
        // --------------------------------------------------------
        // Toile de conception
        // --------------------------------------------------------

        Expanded(
          child: CanvasArea(
            child: previewWidget,
            onBackgroundTap: () {
              ref
                  .read(editorProvider.notifier)
                  .clearSelection();
            },
          ),
        ),

        // --------------------------------------------------------
        // Palette de widgets
        // --------------------------------------------------------

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

        // --------------------------------------------------------
        // Inspecteur de propriétés
        // --------------------------------------------------------

        if (selectedWidget != null)
          Container(
            height: 250,
            width: double.infinity,
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? AppColors.surface
                    : Colors.grey.shade100,
            child: PropertyInspector(
              selectedWidget: selectedWidget,
              onPropertyChanged: (key, value) {
                final currentSelectedWidget = selectedWidget;

                if (currentSelectedWidget == null) {
                  return;
                }

                ref
                    .read(editorProvider.notifier)
                    .updateWidgetProperty(
                      currentSelectedWidget.id,
                      key,
                      value,
                    );
              },
              onDelete: () {
                final currentSelectedWidget = selectedWidget;

                if (currentSelectedWidget == null) {
                  return;
                }

                ref
                    .read(editorProvider.notifier)
                    .removeWidget(
                      currentSelectedWidget.id,
                    );
              },
              onDuplicate: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Duplication à venir',
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}