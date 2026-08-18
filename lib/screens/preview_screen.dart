import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../models/logic_block.dart';
import '../models/page_model.dart';
import '../models/project_model.dart';
import '../providers/project_provider.dart';
import '../providers/variable_store.dart';
import '../render_engine/json_widget_parser.dart';
import '../render_engine/render_context.dart';
import '../render_engine/logic_executor/logic_executor.dart';
import '../render_engine/logic_executor/block_types/navigate_block.dart';

/// Écran d'aperçu en direct du projet.
///
/// Cette version utilise le moteur de rendu modulaire (`JsonWidgetParser`,
/// `RenderContext`) et l'exécuteur logique (`LogicExecutor`) pour interpréter
/// le JSON du projet et exécuter les événements.
///
/// La navigation interne est gérée par une pile de pages. Les blocs
/// `navigate_to` sont interceptés pour mettre à jour cette pile.
class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key});

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  /// Pile de navigation interne (pour les navigate_to).
  final List<String> _pageStack = [];

  @override
  void initState() {
    super.initState();
    final project = ref.read(activeProjectProvider);
    if (project != null) {
      final initialPageId = project.navigation.initialPageId;
      if (initialPageId.isNotEmpty) {
        _pageStack.add(initialPageId);
      } else if (project.pages.isNotEmpty) {
        _pageStack.add(project.pages.first.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(activeProjectProvider);
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.previewTitle)),
        body: const Center(child: Text('Aucun projet actif')),
      );
    }

    // Récupérer les valeurs courantes des variables (réactivité).
    final variableState = ref.watch(variableStoreProvider);
    final currentValues = variableState.currentValues;

    // Déterminer la page courante.
    if (_pageStack.isEmpty) {
      final initial = project.navigation.initialPageId;
      if (initial.isNotEmpty) _pageStack.add(initial);
    }
    final currentPageId = _pageStack.isNotEmpty ? _pageStack.last : null;
    if (currentPageId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.previewTitle)),
        body: const Center(child: Text('Aucune page définie')),
      );
    }

    final page = project.getPageById(currentPageId);
    if (page == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.previewTitle)),
        body: const Center(child: Text('Page introuvable')),
      );
    }

    // Créer le RenderContext avec un callback de mise à jour des variables.
    final renderContext = RenderContext(
      project: project,
      variables: currentValues,
      setVariable: (variableId, value) {
        ref.read(variableStoreProvider.notifier).setValue(variableId, value);
      },
    );

    // Créer le parseur de widgets.
    final parser = JsonWidgetParser(
      context: renderContext,
      onEvent: (widgetId, eventName) => _handleEvent(project, page, widgetId, eventName, renderContext),
    );

    // Construire le widget racine.
    final Widget rootWidget = parser.build(page.rootWidget);

    return Scaffold(
      appBar: AppBar(
        title: Text('${AppStrings.previewTitle} - ${page.name}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_pageStack.length > 1)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _pageStack.removeLast()),
            ),
        ],
      ),
      body: rootWidget,
    );
  }

  /// Gère un événement déclenché par un widget.
  /// [page] : page courante.
  /// [widgetId] : identifiant du widget qui a déclenché l'événement.
  /// [eventName] : nom de l'événement (ex: onPressed).
  /// [renderContext] : contexte de rendu courant.
  void _handleEvent(
    ProjectModel project,
    PageModel page,
    String widgetId,
    String eventName,
    RenderContext renderContext,
  ) {
    final bindings = page.logicBindings;
    if (bindings == null) return;

    final events = bindings[widgetId];
    if (events == null) return;

    final blockMaps = events[eventName];
    if (blockMaps == null || blockMaps.isEmpty) return;

    // Convertir les maps en objets LogicBlock.
    final blocks = blockMaps.map((json) => LogicBlock.fromJson(json)).toList();

    // Créer l'exécuteur logique avec le callback de navigation.
    final executor = LogicExecutor(
      project: project,
      renderContext: renderContext,
      buildContext: context,
      onNavigate: (pageId) {
        setState(() {
          _pageStack.add(pageId);
        });
      },
    );

    // Exécuter les blocs.
    executor.execute(blocks);
  }
}