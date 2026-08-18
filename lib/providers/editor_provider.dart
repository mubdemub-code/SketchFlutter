import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart'; // ou package:flutter/material.dart

import '../models/page_model.dart';
import '../models/project_model.dart';
import '../models/widget_node.dart';
import 'project_provider.dart';

/// État de l'éditeur.
class EditorState {
  /// ID du widget sélectionné (peut être null).
  final String? selectedWidgetId;

  /// ID de la page actuellement affichée/modifiée.
  final String currentPageId;

  /// Pile des états précédents (snapshots du projet) pour undo.
  final List<ProjectModel> undoStack;

  /// Pile des états suivants pour redo.
  final List<ProjectModel> redoStack;

  const EditorState({
    this.selectedWidgetId,
    required this.currentPageId,
    this.undoStack = const [],
    this.redoStack = const [],
  });

  EditorState copyWith({
    String? selectedWidgetId,
    String? currentPageId,
    List<ProjectModel>? undoStack,
    List<ProjectModel>? redoStack,
  }) {
    return EditorState(
      selectedWidgetId: selectedWidgetId ?? this.selectedWidgetId,
      currentPageId: currentPageId ?? this.currentPageId,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
    );
  }

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
}

/// Notifier de l'éditeur : gère la sélection, l'historique et les modifications
/// du projet actif.
class EditorNotifier extends Notifier<EditorState> {
  @override
  EditorState build() {
    // Déterminer la page courante à partir du projet actif.
    final project = ref.watch(activeProjectProvider);
    final initialPageId = project?.navigation.initialPageId ??
        (project?.pages.isNotEmpty == true ? project!.pages.first.id : '');
    return EditorState(currentPageId: initialPageId);
  }

  // ---------------------------------------------------------------------------
  // Gestion de la sélection
  // ---------------------------------------------------------------------------

  void selectWidget(String? widgetId) {
    state = state.copyWith(selectedWidgetId: widgetId);
  }

  void clearSelection() {
    state = state.copyWith(selectedWidgetId: null);
  }

  // ---------------------------------------------------------------------------
  // Gestion de la page courante
  // ---------------------------------------------------------------------------

  void setCurrentPage(String pageId) {
    state = state.copyWith(currentPageId: pageId);
  }

  // ---------------------------------------------------------------------------
  // Historique (undo/redo)
  // ---------------------------------------------------------------------------

  /// Ajoute l'état actuel du projet à la pile undo avant une modification.
  void _pushUndo(ProjectModel currentProject) {
    final newUndoStack = List<ProjectModel>.from(state.undoStack)..add(currentProject);
    // Limiter la taille de la pile pour éviter une consommation mémoire excessive.
    if (newUndoStack.length > 50) {
      newUndoStack.removeAt(0);
    }
    state = state.copyWith(
      undoStack: newUndoStack,
      redoStack: const [], // toute nouvelle modification invalide le redo
    );
  }

  void undo() {
    final project = ref.read(activeProjectProvider);
    if (project == null || state.undoStack.isEmpty) return;

    final previous = state.undoStack.last;
    final newUndoStack = List<ProjectModel>.from(state.undoStack)..removeLast();
    final newRedoStack = List<ProjectModel>.from(state.redoStack)..add(project);

    // Restaurer le projet précédent.
    ref.read(activeProjectProvider.notifier).state = previous;
    state = state.copyWith(
      undoStack: newUndoStack,
      redoStack: newRedoStack,
    );
  }

  void redo() {
    final project = ref.read(activeProjectProvider);
    if (project == null || state.redoStack.isEmpty) return;

    final next = state.redoStack.last;
    final newRedoStack = List<ProjectModel>.from(state.redoStack)..removeLast();
    final newUndoStack = List<ProjectModel>.from(state.undoStack)..add(project);

    ref.read(activeProjectProvider.notifier).state = next;
    state = state.copyWith(
      undoStack: newUndoStack,
      redoStack: newRedoStack,
    );
  }

  // ---------------------------------------------------------------------------
  // Méthodes de modification du projet (avec historique)
  // ---------------------------------------------------------------------------

  /// Ajoute un widget comme enfant d'un widget parent (ou à la racine de la page).
  /// Si parentId est null, ajoute à la racine de la page courante.
  void addWidget(WidgetNode newWidget, {String? parentId}) {
    final project = ref.read(activeProjectProvider);
    if (project == null) return;

    final page = _getCurrentPage(project);
    if (page == null) return;

    _pushUndo(project);

    final updatedPage = _addWidgetToPage(page, newWidget, parentId);
    final updatedPages = project.pages
        .map((p) => p.id == updatedPage.id ? updatedPage : p)
        .toList();
    final updatedProject = project.copyWith(pages: updatedPages);

    ref.read(activeProjectProvider.notifier).state = updatedProject;
    // Sélectionner le nouveau widget.
    state = state.copyWith(selectedWidgetId: newWidget.id);
  }

  /// Supprime un widget par son ID.
  void removeWidget(String widgetId) {
    final project = ref.read(activeProjectProvider);
    if (project == null) return;

    final page = _getCurrentPage(project);
    if (page == null) return;

    _pushUndo(project);

    final newRoot = page.rootWidget.removeNode(widgetId);
    final updatedPage = page.copyWith(rootWidget: newRoot ?? WidgetNode.create(type: 'Container'));
    final updatedPages = project.pages
        .map((p) => p.id == updatedPage.id ? updatedPage : p)
        .toList();
    final updatedProject = project.copyWith(pages: updatedPages);

    ref.read(activeProjectProvider.notifier).state = updatedProject;
    if (state.selectedWidgetId == widgetId) {
      state = state.copyWith(selectedWidgetId: null);
    }
  }

  /// Met à jour une propriété d'un widget.
  void updateWidgetProperty(String widgetId, String propertyKey, dynamic value) {
    final project = ref.read(activeProjectProvider);
    if (project == null) return;

    final page = _getCurrentPage(project);
    if (page == null) return;

    final targetWidget = page.rootWidget.findById(widgetId);
    if (targetWidget == null) return;

    _pushUndo(project);

    final updatedWidget = targetWidget.copyWith(
      properties: {
        ...?targetWidget.properties,
        propertyKey: value,
      },
    );
    final updatedRoot = page.rootWidget.replaceNode(widgetId, updatedWidget);
    final updatedPage = page.copyWith(rootWidget: updatedRoot);
    final updatedPages = project.pages
        .map((p) => p.id == updatedPage.id ? updatedPage : p)
        .toList();
    final updatedProject = project.copyWith(pages: updatedPages);

    ref.read(activeProjectProvider.notifier).state = updatedProject;
  }

  /// Déplace un widget existant vers un nouveau parent (ou à la racine).
  void moveWidget(String widgetId, {String? newParentId, int? index}) {
    // Implémentation simplifiée : on retire puis on réinsère.
    final project = ref.read(activeProjectProvider);
    if (project == null) return;

    final page = _getCurrentPage(project);
    if (page == null) return;

    final widgetToMove = page.rootWidget.findById(widgetId);
    if (widgetToMove == null) return;

    // Vérifier qu'on ne déplace pas un parent dans son propre enfant.
    if (newParentId != null && _isDescendant(widgetToMove, newParentId)) {
      return;
    }

    _pushUndo(project);

    // Retirer de l'ancien emplacement.
    final rootAfterRemoval = page.rootWidget.removeNode(widgetId);
    // Réinsérer.
    final rootAfterInsert = _insertWidget(
      rootAfterRemoval ?? page.rootWidget,
      widgetToMove,
      newParentId,
      index,
    );
    final updatedPage = page.copyWith(rootWidget: rootAfterInsert);
    final updatedPages = project.pages
        .map((p) => p.id == updatedPage.id ? updatedPage : p)
        .toList();
    final updatedProject = project.copyWith(pages: updatedPages);

    ref.read(activeProjectProvider.notifier).state = updatedProject;
  }

  // ---------------------------------------------------------------------------
  // Helpers internes
  // ---------------------------------------------------------------------------

  PageModel? _getCurrentPage(ProjectModel project) {
    return project.getPageById(state.currentPageId);
  }

  /// Vérifie si un widget [ancestor] est un ancêtre de [nodeId].
  bool _isDescendant(WidgetNode ancestor, String nodeId) {
    if (ancestor.id == nodeId) return true;
    if (ancestor.child != null && _isDescendant(ancestor.child!, nodeId)) {
      return true;
    }
    if (ancestor.children != null) {
      for (final child in ancestor.children!) {
        if (_isDescendant(child, nodeId)) return true;
      }
    }
    return false;
  }

  /// Ajoute un widget à la page (racine ou sous un parent).
  PageModel _addWidgetToPage(PageModel page, WidgetNode widget, String? parentId) {
    if (parentId == null) {
      // Ajouter à la racine. Si la racine est un Container vide, on peut le remplacer.
      // Ici, on crée un nouveau Scaffold avec le widget comme body.
      // Pour simplifier, on suppose que la racine est un Scaffold et on ajoute le widget
      // comme enfant de son body (ou on crée un Scaffold si pas déjà).
      // Nous allons plutôt remplacer le rootWidget par un nouveau root qui contient l'ancien et le nouveau
      // en tant que children si possible, sinon on crée un Column.
      // Pour rester simple, on va considérer que le rootWidget a un type 'Column' ou 'Scaffold' et on ajoute.
      // Mais pour un usage générique, on crée un Column avec les anciens enfants et le nouveau.
      // Néanmoins, dans l'éditeur, on aura généralement un Scaffold avec un body.
      // On va gérer le cas où le rootWidget n'a pas de children : on le remplace par un Column contenant les deux.
      final currentRoot = page.rootWidget;
      if (currentRoot.type == 'Scaffold') {
        // On ajoute au body du Scaffold.
        final body = currentRoot.child;
        if (body != null && body.type == 'Column') {
          final newChildren = List<WidgetNode>.from(body.children ?? [])..add(widget);
          final updatedBody = body.copyWith(children: newChildren);
          final updatedRoot = currentRoot.copyWith(child: updatedBody);
          return page.copyWith(rootWidget: updatedRoot);
        } else {
          // Créer un Column contenant l'ancien body et le nouveau.
          final newColumn = WidgetNode.create(
            type: 'Column',
            children: [
              if (body != null) body,
              widget,
            ],
          );
          final updatedRoot = currentRoot.copyWith(child: newColumn);
          return page.copyWith(rootWidget: updatedRoot);
        }
      } else if (currentRoot.type == 'Column') {
        final newChildren = List<WidgetNode>.from(currentRoot.children ?? [])..add(widget);
        final updatedRoot = currentRoot.copyWith(children: newChildren);
        return page.copyWith(rootWidget: updatedRoot);
      } else {
        // Remplacer par une Column avec l'ancien root et le nouveau.
        final newRoot = WidgetNode.create(
          type: 'Column',
          children: [currentRoot, widget],
        );
        return page.copyWith(rootWidget: newRoot);
      }
    } else {
      // Ajouter sous un parent existant.
      final parentWidget = page.rootWidget.findById(parentId);
      if (parentWidget == null) return page;

      if (parentWidget.type == 'Container' || parentWidget.type == 'Scaffold') {
        // Si le parent a déjà un child, on crée un Column pour accueillir les deux.
        if (parentWidget.child != null) {
          final newColumn = WidgetNode.create(
            type: 'Column',
            children: [parentWidget.child!, widget],
          );
          final updatedParent = parentWidget.copyWith(child: newColumn);
          final updatedRoot = page.rootWidget.replaceNode(parentId, updatedParent);
          return page.copyWith(rootWidget: updatedRoot);
        } else {
          final updatedParent = parentWidget.copyWith(child: widget);
          final updatedRoot = page.rootWidget.replaceNode(parentId, updatedParent);
          return page.copyWith(rootWidget: updatedRoot);
        }
      } else if (parentWidget.type == 'Column' || parentWidget.type == 'Row') {
        final newChildren = List<WidgetNode>.from(parentWidget.children ?? [])..add(widget);
        final updatedParent = parentWidget.copyWith(children: newChildren);
        final updatedRoot = page.rootWidget.replaceNode(parentId, updatedParent);
        return page.copyWith(rootWidget: updatedRoot);
      } else {
        // Pour les autres types, on ne peut pas ajouter directement, on ignore.
        return page;
      }
    }
  }

  /// Insère un widget dans l'arbre à une position donnée.
  WidgetNode _insertWidget(WidgetNode root, WidgetNode widget, String? parentId, int? index) {
    if (parentId == null) {
      // Insérer à la racine (même logique que addWidget).
      // Pour simplifier, on crée un Column avec tous les anciens enfants plus le widget inséré.
      // Cela suppose que la racine est un Column.
      if (root.type == 'Column') {
        final children = List<WidgetNode>.from(root.children ?? []);
        if (index != null && index >= 0 && index <= children.length) {
          children.insert(index, widget);
        } else {
          children.add(widget);
        }
        return root.copyWith(children: children);
      } else {
        // Si ce n'est pas un Column, on le convertit en Column.
        final children = [root];
        if (index != null && index >= 0 && index <= children.length) {
          children.insert(index, widget);
        } else {
          children.add(widget);
        }
        return WidgetNode.create(type: 'Column', children: children);
      }
    } else {
      // Insérer sous un parent.
      // On peut utiliser la même logique que pour l'ajout, en gérant l'index.
      final parent = root.findById(parentId);
      if (parent == null) return root;

      WidgetNode updatedParent;
      if (parent.type == 'Column' || parent.type == 'Row') {
        final children = List<WidgetNode>.from(parent.children ?? []);
        if (index != null && index >= 0 && index <= children.length) {
          children.insert(index, widget);
        } else {
          children.add(widget);
        }
        updatedParent = parent.copyWith(children: children);
      } else if (parent.child != null) {
        // Convertir en Column avec l'ancien child et le nouveau.
        final children = [parent.child!];
        if (index != null && index >= 0 && index <= children.length) {
          children.insert(index, widget);
        } else {
          children.add(widget);
        }
        updatedParent = parent.copyWith(
          child: WidgetNode.create(type: 'Column', children: children),
        );
      } else {
        updatedParent = parent.copyWith(child: widget);
      }
      return root.replaceNode(parentId, updatedParent);
    }
  }
}

/// Provider de l'éditeur.
final editorProvider = NotifierProvider<EditorNotifier, EditorState>(EditorNotifier.new);