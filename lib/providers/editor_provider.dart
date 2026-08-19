import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/page_model.dart';
import '../models/project_model.dart';
import '../models/widget_node.dart';
import 'project_provider.dart';

/// ============================================================================
/// ÉTAT DE L'ÉDITEUR
/// ============================================================================

class EditorState {
  /// Widget actuellement sélectionné.
  final String? selectedWidgetId;

  /// Page actuellement affichée.
  final String currentPageId;

  /// Historique undo.
  final List<ProjectModel> undoStack;

  /// Historique redo.
  final List<ProjectModel> redoStack;

  const EditorState({
    this.selectedWidgetId,
    required this.currentPageId,
    this.undoStack = const <ProjectModel>[],
    this.redoStack = const <ProjectModel>[],
  });

  /// [clearSelectedWidgetId] permet de réellement mettre la sélection à null.
  ///
  /// C'est important car :
  ///
  ///     selectedWidgetId ?? this.selectedWidgetId
  ///
  /// empêcherait auparavant de vider la sélection.
  EditorState copyWith({
    String? selectedWidgetId,
    bool clearSelectedWidgetId = false,
    String? currentPageId,
    List<ProjectModel>? undoStack,
    List<ProjectModel>? redoStack,
  }) {
    return EditorState(
      selectedWidgetId: clearSelectedWidgetId
          ? null
          : selectedWidgetId ?? this.selectedWidgetId,
      currentPageId:
          currentPageId ?? this.currentPageId,
      undoStack:
          undoStack ?? this.undoStack,
      redoStack:
          redoStack ?? this.redoStack,
    );
  }

  bool get canUndo => undoStack.isNotEmpty;

  bool get canRedo => redoStack.isNotEmpty;

  int get undoCount => undoStack.length;

  int get redoCount => redoStack.length;
}

/// ============================================================================
/// POSITION D'INSERTION
/// ============================================================================

enum WidgetInsertPosition {
  inside,
  before,
  after,
}

/// ============================================================================
/// RÉSULTAT D'OPÉRATION
/// ============================================================================

class EditorOperationResult {
  final bool success;
  final String? message;
  final String? affectedWidgetId;

  const EditorOperationResult({
    required this.success,
    this.message,
    this.affectedWidgetId,
  });

  const EditorOperationResult.success({
    String? message,
    String? affectedWidgetId,
  }) : this(
          success: true,
          message: message,
          affectedWidgetId: affectedWidgetId,
        );

  const EditorOperationResult.failure(
    String message,
  ) : this(
          success: false,
          message: message,
        );
}

/// ============================================================================
/// NOTIFIER PRINCIPAL
/// ============================================================================
///
/// Ce provider est le cœur structurel du Design Studio.
///
/// Il manipule uniquement le modèle ProjectModel immuable.
/// Le moteur de rendu n'a donc pas besoin de connaître la façon dont
/// l'arbre est modifié.
///
/// Architecture :
///
/// UI
///  │
///  ▼
/// EditorNotifier
///  │
///  ├── sélection
///  ├── insertion
///  ├── déplacement
///  ├── duplication
///  ├── suppression
///  ├── reorder
///  ├── propriétés
///  ├── undo / redo
///  └── transactions
///  │
///  ▼
/// ProjectModel
///
class EditorNotifier extends Notifier<EditorState> {
  // ==========================================================================
  // CONFIGURATION
  // ==========================================================================

  static const int maxHistorySize = 100;

  // ==========================================================================
  // TRANSACTION
  // ==========================================================================

  int _transactionDepth = 0;

  ProjectModel? _transactionSnapshot;

  bool _transactionChanged = false;

  // ==========================================================================
  // INITIALISATION
  // ==========================================================================

  @override
  EditorState build() {
    final project = ref.watch(activeProjectProvider);

    final String initialPageId;

    if (project == null) {
      initialPageId = '';
    } else if (project.navigation.initialPageId.isNotEmpty) {
      initialPageId =
          project.navigation.initialPageId;
    } else if (project.pages.isNotEmpty) {
      initialPageId =
          project.pages.first.id;
    } else {
      initialPageId = '';
    }

    return EditorState(
      currentPageId: initialPageId,
    );
  }

  // ==========================================================================
  // SÉLECTION
  // ==========================================================================

  void selectWidget(String? widgetId) {
    if (widgetId == null || widgetId.isEmpty) {
      clearSelection();
      return;
    }

    final project = ref.read(activeProjectProvider);

    if (project == null) {
      state = state.copyWith(
        clearSelectedWidgetId: true,
      );
      return;
    }

    final page = _getCurrentPage(project);

    if (page == null || page.rootWidget == null) {
      state = state.copyWith(
        clearSelectedWidgetId: true,
      );
      return;
    }

    final node =
        page.rootWidget!.findById(widgetId);

    if (node == null) {
      state = state.copyWith(
        clearSelectedWidgetId: true,
      );
      return;
    }

    state = state.copyWith(
      selectedWidgetId: node.id,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      clearSelectedWidgetId: true,
    );
  }

  WidgetNode? getSelectedWidget() {
    final project = ref.read(activeProjectProvider);

    if (project == null ||
        state.selectedWidgetId == null) {
      return null;
    }

    final page = _getCurrentPage(project);

    if (page?.rootWidget == null) {
      return null;
    }

    return page!.rootWidget!.findById(
      state.selectedWidgetId!,
    );
  }

  // ==========================================================================
  // PAGE COURANTE
  // ==========================================================================

  void setCurrentPage(String pageId) {
    if (pageId.isEmpty) {
      return;
    }

    final project = ref.read(activeProjectProvider);

    if (project != null) {
      final page =
          project.getPageById(pageId);

      if (page == null) {
        return;
      }
    }

    state = state.copyWith(
      currentPageId: pageId,
      clearSelectedWidgetId: true,
    );
  }

  PageModel? getCurrentPage() {
    final project =
        ref.read(activeProjectProvider);

    if (project == null) {
      return null;
    }

    return _getCurrentPage(project);
  }

  // ==========================================================================
  // HISTORIQUE
  // ==========================================================================

  void _pushUndo(ProjectModel project) {
    if (_transactionDepth > 0) {
      _transactionSnapshot ??= project;
      _transactionChanged = true;
      return;
    }

    final undo =
        List<ProjectModel>.from(
      state.undoStack,
    )..add(project);

    if (undo.length > maxHistorySize) {
      undo.removeRange(
        0,
        undo.length - maxHistorySize,
      );
    }

    state = state.copyWith(
      undoStack: undo,
      redoStack: const <ProjectModel>[],
    );
  }

  void _commitTransactionIfNeeded() {
    if (_transactionDepth != 0) {
      return;
    }

    if (!_transactionChanged ||
        _transactionSnapshot == null) {
      _transactionSnapshot = null;
      _transactionChanged = false;
      return;
    }

    final snapshot =
        _transactionSnapshot!;

    final undo =
        List<ProjectModel>.from(
      state.undoStack,
    )..add(snapshot);

    if (undo.length > maxHistorySize) {
      undo.removeRange(
        0,
        undo.length - maxHistorySize,
      );
    }

    state = state.copyWith(
      undoStack: undo,
      redoStack: const <ProjectModel>[],
    );

    _transactionSnapshot = null;
    _transactionChanged = false;
  }

  /// Commence une transaction.
  ///
  /// Exemple :
  ///
  ///     beginTransaction();
  ///     updateWidgetProperty(...);
  ///     updateWidgetProperty(...);
  ///     updateWidgetProperty(...);
  ///     endTransaction();
  ///
  /// => une seule entrée dans Undo.
  void beginTransaction() {
    _transactionDepth++;
  }

  /// Termine la transaction.
  void endTransaction() {
    if (_transactionDepth <= 0) {
      _transactionDepth = 0;
      return;
    }

    _transactionDepth--;

    if (_transactionDepth == 0) {
      _commitTransactionIfNeeded();
    }
  }

  void cancelTransaction() {
    _transactionDepth = 0;
    _transactionSnapshot = null;
    _transactionChanged = false;
  }

  void clearHistory() {
    state = state.copyWith(
      undoStack: const <ProjectModel>[],
      redoStack: const <ProjectModel>[],
    );
  }

  // ==========================================================================
  // UNDO
  // ==========================================================================

  void undo() {
    final project =
        ref.read(activeProjectProvider);

    if (project == null ||
        state.undoStack.isEmpty) {
      return;
    }

    final previous =
        state.undoStack.last;

    final undo =
        List<ProjectModel>.from(
      state.undoStack,
    )..removeLast();

    final redo =
        List<ProjectModel>.from(
      state.redoStack,
    )..add(project);

    if (redo.length > maxHistorySize) {
      redo.removeRange(
        0,
        redo.length - maxHistorySize,
      );
    }

    ref
        .read(activeProjectProvider.notifier)
        .state = previous;

    state = state.copyWith(
      undoStack: undo,
      redoStack: redo,
    );

    _restoreSelectionAfterProjectChange(
      previous,
    );
  }

  // ==========================================================================
  // REDO
  // ==========================================================================

  void redo() {
    final project =
        ref.read(activeProjectProvider);

    if (project == null ||
        state.redoStack.isEmpty) {
      return;
    }

    final next =
        state.redoStack.last;

    final redo =
        List<ProjectModel>.from(
      state.redoStack,
    )..removeLast();

    final undo =
        List<ProjectModel>.from(
      state.undoStack,
    )..add(project);

    if (undo.length > maxHistorySize) {
      undo.removeRange(
        0,
        undo.length - maxHistorySize,
      );
    }

    ref
        .read(activeProjectProvider.notifier)
        .state = next;

    state = state.copyWith(
      undoStack: undo,
      redoStack: redo,
    );

    _restoreSelectionAfterProjectChange(
      next,
    );
  }

  // ==========================================================================
  // AJOUT D'UN WIDGET
  // ==========================================================================

  void addWidget(
    WidgetNode newWidget, {
    String? parentId,
    int? index,
  }) {
    final project =
        ref.read(activeProjectProvider);

    if (project == null) {
      return;
    }

    final page =
        _getCurrentPage(project);

    if (page == null ||
        page.rootWidget == null) {
      return;
    }

    if (_containsDuplicateId(
      page.rootWidget!,
      newWidget.id,
    )) {
      return;
    }

    _pushUndo(project);

    final result =
        _insertIntoTree(
      page.rootWidget!,
      newWidget,
      parentId: parentId,
      index: index,
    );

    if (!result.changed) {
      return;
    }

    final updatedPage =
        page.copyWith(
      rootWidget: result.root,
    );

    final updatedProject =
        _replacePageInProject(
      project,
      updatedPage,
    );

    _setProject(
      updatedProject,
      selectedWidgetId:
          newWidget.id,
    );
  }

  // ==========================================================================
  // AJOUT AVANT / APRÈS
  // ==========================================================================

  void insertWidgetBefore(
    String targetWidgetId,
    WidgetNode widget,
  ) {
    _insertRelative(
      targetWidgetId,
      widget,
      before: true,
    );
  }

  void insertWidgetAfter(
    String targetWidgetId,
    WidgetNode widget,
  ) {
    _insertRelative(
      targetWidgetId,
      widget,
      before: false,
    );
  }

  void _insertRelative(
    String targetWidgetId,
    WidgetNode widget, {
    required bool before,
  }) {
    final project =
        ref.read(activeProjectProvider);

    if (project == null) {
      return;
    }

    final page =
        _getCurrentPage(project);

    if (page?.rootWidget == null) {
      return;
    }

    final root =
        page!.rootWidget!;

    final parent =
        _findParentNode(
      root,
      targetWidgetId,
    );

    if (parent == null) {
      return;
    }

    final targetIndex =
        _indexOfChild(
      parent,
      targetWidgetId,
    );

    if (targetIndex < 0) {
      return;
    }

    final index =
        before
            ? targetIndex
            : targetIndex + 1;

    addWidget(
      widget,
      parentId: parent.id,
      index: index,
    );
  }

  // ==========================================================================
  // SUPPRESSION
  // ==========================================================================

  void removeWidget(
    String widgetId,
  ) {
    final project =
        ref.read(activeProjectProvider);

    if (project == null) {
      return;
    }

    final page =
        _getCurrentPage(project);

    if (page?.rootWidget == null) {
      return;
    }

    final root =
        page!.rootWidget!;

    if (root.id == widgetId) {
      _removeRootWidget(
        project,
        page,
      );
      return;
    }

    final target =
        root.findById(widgetId);

    if (target == null) {
      return;
    }

    _pushUndo(project);

    final newRoot =
        root.removeNode(
      widgetId,
    );

    if (newRoot == null) {
      return;
    }

    final updatedPage =
        page.copyWith(
      rootWidget: newRoot,
    );

    final updatedProject =
        _replacePageInProject(
      project,
      updatedPage,
    );

    final bool clear =
        state.selectedWidgetId ==
            widgetId;

    _setProject(
      updatedProject,
      clearSelection: clear,
    );
  }

  void _removeRootWidget(
    ProjectModel project,
    PageModel page,
  ) {
    _pushUndo(project);

    /// Une page doit toujours conserver
    /// un root valide pour l'éditeur.
    final replacement =
        _createSafeEmptyRoot();

    final updatedPage =
        page.copyWith(
      rootWidget: replacement,
    );

    final updatedProject =
        _replacePageInProject(
      project,
      updatedPage,
    );

    _setProject(
      updatedProject,
      clearSelection: true,
    );
  }

  WidgetNode _createSafeEmptyRoot() {
    return WidgetNode.create(
      type: 'Scaffold',
      properties:
          <String, dynamic>{},
      children: <WidgetNode>[
        WidgetNode.create(
          type: 'Container',
          properties:
              <String, dynamic>{
            'color':
                '#FFFFFFFF',
          },
          children:
              <WidgetNode>[],
        ),
      ],
    );
  }

  // ==========================================================================
  // MODIFICATION D'UNE PROPRIÉTÉ
  // ==========================================================================

  void updateWidgetProperty(
    String widgetId,
    String propertyKey,
    dynamic value,
  ) {
    updateWidgetProperties(
      widgetId,
      <String, dynamic>{
        propertyKey: value,
      },
    );
  }

  void updateWidgetProperties(
    String widgetId,
    Map<String, dynamic> changes,
  ) {
    if (changes.isEmpty) {
      return;
    }

    final project =
        ref.read(activeProjectProvider);

    if (project == null) {
      return;
    }

    final page =
        _getCurrentPage(project);

    if (page?.rootWidget == null) {
      return;
    }

    final root =
        page!.rootWidget!;

    final target =
        root.findById(widgetId);

    if (target == null) {
      return;
    }

    final merged =
        <String, dynamic>{
      ...?target.properties,
      ...changes,
    };

    final updatedWidget =
        target.copyWith(
      properties: merged,
    );

    _pushUndo(project);

    final updatedRoot =
        root.replaceNode(
      widgetId,
      updatedWidget,
    );

    final updatedPage =
        page.copyWith(
      rootWidget: updatedRoot,
    );

    final updatedProject =
        _replacePageInProject(
      project,
      updatedPage,
    );

    _setProject(
      updatedProject,
      selectedWidgetId:
          widgetId,
    );
  }

  /// Remplace totalement un widget.
  void replaceWidget(
    String widgetId,
    WidgetNode replacement,
  ) {
    final project =
        ref.read(activeProjectProvider);

    if (project == null) {
      return;
    }

    final page =
        _getCurrentPage(project);

    if (page?.rootWidget == null) {
      return;
    }

    final root =
        page!.rootWidget!;

    if (root.findById(widgetId) ==
        null) {
      return;
    }

    _pushUndo(project);

    final updatedRoot =
        root.replaceNode(
      widgetId,
      replacement,
    );

    final updatedPage =
        page.copyWith(
      rootWidget: updatedRoot,
    );

    final updatedProject =
        _replacePageInProject(
      project,
      updatedPage,
    );

    _setProject(
      updatedProject,
      selectedWidgetId:
          replacement.id,
    );
  }

  // ==========================================================================
  // DÉPLACEMENT
  // ==========================================================================

  void moveWidget(
    String widgetId, {
    String? newParentId,
    int? index,
  }) {
    final project =
        ref.read(activeProjectProvider);

    if (project == null) {
      return;
    }

    final page =
        _getCurrentPage(project);

    if (page?.rootWidget == null) {
      return;
    }

    final root =
        page!.rootWidget!;

    final widgetToMove =
        root.findById(widgetId);

    if (widgetToMove == null) {
      return;
    }

    // Impossible de placer un nœud dans lui-même
    if (newParentId == widgetId) {
      return;
    }

    // Impossible de placer un parent dans
    // un de ses descendants.
    if (newParentId != null &&
        _isDescendant(
          widgetToMove,
          newParentId,
        )) {
      return;
    }

    final sourceParent =
        _findParentNode(
      root,
      widgetId,
    );

    // Déplacement vers exactement le même parent.
    if (sourceParent != null &&
        sourceParent.id ==
            newParentId) {
      _reorderWithinSameParent(
        project,
        page,
        root,
        widgetId,
        sourceParent,
        index,
      );

      return;
    }

    _pushUndo(project);

    // Retirer l'ancien emplacement.
    final afterRemoval =
        root.removeNode(
      widgetId,
    );

    if (afterRemoval == null) {
      return;
    }

    // Réinsérer le même sous-arbre.
    final insertion =
        _insertIntoTree(
      afterRemoval,
      widgetToMove,
      parentId: newParentId,
      index: index,
    );

    if (!insertion.changed) {
      return;
    }

    final updatedPage =
        page.copyWith(
      rootWidget:
          insertion.root,
    );

    final updatedProject =
        _replacePageInProject(
      project,
      updatedPage,
    );

    _setProject(
      updatedProject,
      selectedWidgetId:
          widgetId,
    );
  }

  // ==========================================================================
  // REORDER DANS LE MÊME PARENT
  // ==========================================================================

  void reorderWidget(
    String widgetId,
    int newIndex,
  ) {
    final project =
        ref.read(activeProjectProvider);

    if (project == null) {
      return;
    }

    final page =
        _getCurrentPage(project);

    if (page?.rootWidget == null) {
      return;
    }

    final root =
        page!.rootWidget!;

    final parent =
        _findParentNode(
      root,
      widgetId,
    );

    if (parent == null) {
      return;
    }

    _reorderWithinSameParent(
      project,
      page,
      root,
      widgetId,
      parent,
      newIndex,
    );
  }

  void _reorderWithinSameParent(
    ProjectModel project,
    PageModel page,
    WidgetNode root,
    String widgetId,
    WidgetNode parent,
    int? requestedIndex,
  ) {
    final children =
        List<WidgetNode>.from(
      parent.children ?? <WidgetNode>[],
    );

    final oldIndex =
        children.indexWhere(
      (child) => child.id == widgetId,
    );

    if (oldIndex < 0) {
      return;
    }

    if (children.length <= 1) {
      return;
    }

    int newIndex =
        requestedIndex ?? children.length - 1;

    newIndex =
        newIndex.clamp(
      0,
      children.length - 1,
    );

    if (oldIndex == newIndex) {
      return;
    }

    _pushUndo(project);

    final node =
        children.removeAt(
      oldIndex,
    );

    if (oldIndex < newIndex) {
      newIndex--;
    }

    newIndex =
        newIndex.clamp(
      0,
      children.length,
    );

    children.insert(
      newIndex,
      node,
    );

    final updatedParent =
        parent.copyWith(
      children: children,
    );

    final updatedRoot =
        root.replaceNode(
      parent.id,
      updatedParent,
    );

    final updatedPage =
        page.copyWith(
      rootWidget:
          updatedRoot,
    );

    final updatedProject =
        _replacePageInProject(
      project,
      updatedPage,
    );

    _setProject(
      updatedProject,
      selectedWidgetId:
          widgetId,
    );
  }

  // ==========================================================================
  // DUPLICATION
  // ==========================================================================

  void duplicateWidget(
    String widgetId, {
    String? parentId,
    int? index,
  }) {
    final project =
        ref.read(activeProjectProvider);

    if (project == null) {
      return;
    }

    final page =
        _getCurrentPage(project);

    if (page?.rootWidget == null) {
      return;
    }

    final root =
        page!.rootWidget!;

    final target =
        root.findById(widgetId);

    if (target == null) {
      return;
    }

    final clone =
        _cloneWidgetTree(
      target,
    );

    if (clone == null) {
      return;
    }

    final actualParent =
        parentId ??
        _findParentNode(
          root,
          widgetId,
        )?.id;

    int? actualIndex =
        index;

    if (actualIndex == null &&
        actualParent != null) {
      final parent =
          root.findById(
        actualParent,
      );

      if (parent != null) {
        final originalIndex =
            _indexOfChild(
          parent,
          widgetId,
        );

        actualIndex =
            originalIndex < 0
                ? null
                : originalIndex + 1;
      }
    }

    addWidget(
      clone,
      parentId: actualParent,
      index: actualIndex,
    );
  }

  // ==========================================================================
  // CLONAGE PROFOND
  // ==========================================================================

  WidgetNode? _cloneWidgetTree(
    WidgetNode original,
  ) {
    final properties =
        _deepCloneMap(
      original.properties,
    );

    final clonedChildren =
        <WidgetNode>[];

    final originalChildren =
        original.children;

    if (originalChildren != null) {
      for (final child
          in originalChildren) {
        final clonedChild =
            _cloneWidgetTree(
          child,
        );

        if (clonedChild != null) {
          clonedChildren.add(
            clonedChild,
          );
        }
      }
    }

    WidgetNode? clonedChild;

    if (original.child != null) {
      clonedChild =
          _cloneWidgetTree(
        original.child!,
      );
    }

    /// On repart de WidgetNode.create()
    /// pour générer un nouvel ID.
    return WidgetNode.create(
      type: original.type,
      properties: properties,
      child: clonedChild,
      children:
          clonedChildren,
    );
  }

  Map<String, dynamic> _deepCloneMap(
    Map<String, dynamic>? map,
  ) {
    if (map == null) {
      return <String, dynamic>{};
    }

    final result =
        <String, dynamic>{};

    map.forEach(
      (key, value) {
        result[key] =
            _deepCloneValue(value);
      },
    );

    return result;
  }

  dynamic _deepCloneValue(
    dynamic value,
  ) {
    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(
          key,
          _deepCloneValue(value),
        ),
      );
    }

    if (value is List) {
      return value
          .map(
            _deepCloneValue,
          )
          .toList();
    }

    return value;
  }

  // ==========================================================================
  // WRAP D'UN WIDGET
  // ==========================================================================

  void wrapWidget(
    String widgetId,
    String wrapperType, {
    Map<String, dynamic> properties =
        const <String, dynamic>{},
  }) {
    final project =
        ref.read(activeProjectProvider);

    if (project == null) {
      return;
    }

    final page =
        _getCurrentPage(project);

    if (page?.rootWidget == null) {
      return;
    }

    final root =
        page!.rootWidget!;

    final target =
        root.findById(widgetId);

    if (target == null) {
      return;
    }

    final wrapper =
        WidgetNode.create(
      type: wrapperType,
      properties: Map<String, dynamic>.from(
        properties,
      ),
      child: target,
    );

    _pushUndo(project);

    final updatedRoot =
        root.replaceNode(
      widgetId,
      wrapper,
    );

    final updatedPage =
        page.copyWith(
      rootWidget:
          updatedRoot,
    );

    final updatedProject =
        _replacePageInProject(
      project,
      updatedPage,
    );

    _setProject(
      updatedProject,
      selectedWidgetId:
          wrapper.id,
    );
  }

  // ==========================================================================
  // UNWRAP
  // ==========================================================================

  void unwrapWidget(
    String widgetId,
  ) {
    final project =
        ref.read(activeProjectProvider);

    if (project == null) {
      return;
    }

    final page =
        _getCurrentPage(project);

    if (page?.rootWidget == null) {
      return;
    }

    final root =
        page!.rootWidget!;

    final target =
        root.findById(widgetId);

    if (target == null ||
        target.child == null) {
      return;
    }

    _pushUndo(project);

    final updatedRoot =
        root.replaceNode(
      widgetId,
      target.child!,
    );

    final updatedPage =
        page.copyWith(
      rootWidget:
          updatedRoot,
    );

    final updatedProject =
        _replacePageInProject(
      project,
      updatedPage,
    );

    _setProject(
      updatedProject,
      selectedWidgetId:
          target.child!.id,
    );
  }

  // ==========================================================================
  // DÉPLACEMENT VERS UN INDEX
  // ==========================================================================

  void moveWidgetBefore(
    String widgetId,
    String targetId,
  ) {
    _moveRelative(
      widgetId,
      targetId,
      before: true,
    );
  }

  void moveWidgetAfter(
    String widgetId,
    String targetId,
  ) {
    _moveRelative(
      widgetId,
      targetId,
      before: false,
    );
  }

  void _moveRelative(
    String widgetId,
    String targetId, {
    required bool before,
  }) {
    final project =
        ref.read(activeProjectProvider);

    if (project == null) {
      return;
    }

    final page =
        _getCurrentPage(project);

    if (page?.rootWidget == null) {
      return;
    }

    final root =
        page!.rootWidget!;

    if (widgetId == targetId) {
      return;
    }

    final target =
        root.findById(targetId);

    if (target == null) {
      return;
    }

    final targetParent =
        _findParentNode(
      root,
      targetId,
    );

    if (targetParent == null) {
      return;
    }

    final targetIndex =
        _indexOfChild(
      targetParent,
      targetId,
    );

    if (targetIndex < 0) {
      return;
    }

    moveWidget(
      widgetId,
      newParentId:
          targetParent.id,
      index: before
          ? targetIndex
          : targetIndex + 1,
    );
  }

  // ==========================================================================
  // INSERTION DANS L'ARBRE
  // ==========================================================================

  _TreeMutationResult _insertIntoTree(
    WidgetNode root,
    WidgetNode widget, {
    String? parentId,
    int? index,
  }) {
    // ------------------------------------------------------------------------
    // RACINE
    // ------------------------------------------------------------------------

    if (parentId == null) {
      return _insertAtRoot(
        root,
        widget,
        index,
      );
    }

    // ------------------------------------------------------------------------
    // PARENT
    // ------------------------------------------------------------------------

    final parent =
        root.findById(parentId);

    if (parent == null) {
      return _TreeMutationResult(
        root: root,
        changed: false,
      );
    }

    if (!_canAcceptChildren(
      parent.type,
    )) {
      return _TreeMutationResult(
        root: root,
        changed: false,
      );
    }

    return _insertIntoParent(
      root,
      parent,
      widget,
      index,
    );
  }

  // ==========================================================================
  // INSERTION RACINE
  // ==========================================================================

  _TreeMutationResult _insertAtRoot(
    WidgetNode root,
    WidgetNode widget,
    int? index,
  ) {
    if (root.type == 'Column') {
      final children =
          List<WidgetNode>.from(
        root.children ?? <WidgetNode>[],
      );

      _insertAtSafeIndex(
        children,
        widget,
        index,
      );

      return _TreeMutationResult(
        root: root.copyWith(
          children: children,
        ),
        changed: true,
      );
    }

    // Un Scaffold garde son rôle de root.
    if (root.type == 'Scaffold') {
      return _insertIntoScaffoldRoot(
        root,
        widget,
        index,
      );
    }

    // Sinon on fabrique un Column
    // sans perdre l'ancien root.
    final children =
        <WidgetNode>[
      root,
    ];

    if (index == null ||
        index >= children.length) {
      children.add(widget);
    } else {
      _insertAtSafeIndex(
        children,
        widget,
        index,
      );
    }

    return _TreeMutationResult(
      root: WidgetNode.create(
        type: 'Column',
        properties:
            <String, dynamic>{},
        children: children,
      ),
      changed: true,
    );
  }

  // ==========================================================================
  // INSERTION DANS SCAFFOLD
  // ==========================================================================

  _TreeMutationResult _insertIntoScaffoldRoot(
    WidgetNode scaffold,
    WidgetNode widget,
    int? index,
  ) {
    final appBarNode =
        _findDirectChildByType(
      scaffold,
      'AppBar',
    );

    final bodyNode =
        _findScaffoldBody(
      scaffold,
    );

    // Body absent.
    if (bodyNode == null) {
      final updated =
          scaffold.copyWith(
        child: widget,
      );

      return _TreeMutationResult(
        root: updated,
        changed: true,
      );
    }

    // Body déjà Column.
    if (bodyNode.type ==
        'Column') {
      final bodyChildren =
          List<WidgetNode>.from(
        bodyNode.children ??
            <WidgetNode>[],
      );

      _insertAtSafeIndex(
        bodyChildren,
        widget,
        index,
      );

      final updatedBody =
          bodyNode.copyWith(
        children: bodyChildren,
      );

      final updatedScaffold =
          scaffold.replaceNode(
        bodyNode.id,
        updatedBody,
      );

      return _TreeMutationResult(
        root: updatedScaffold,
        changed: true,
      );
    }

    // Body unique -> transformation en Column.
    final bodyColumn =
        WidgetNode.create(
      type: 'Column',
      properties:
          <String, dynamic>{},
      children: <WidgetNode>[
        bodyNode,
        widget,
      ],
    );

    if (index == 0) {
      bodyColumn.children.removeAt(0);
      bodyColumn.children.insert(
        0,
        widget,
      );
      bodyColumn.children.add(
        bodyNode,
      );
    }

    final updatedScaffold =
        scaffold.replaceNode(
      bodyNode.id,
      bodyColumn,
    );

    return _TreeMutationResult(
      root: updatedScaffold,
      changed: true,
    );
  }

  // ==========================================================================
  // INSERTION DANS PARENT
  // ==========================================================================

  _TreeMutationResult _insertIntoParent(
    WidgetNode root,
    WidgetNode parent,
    WidgetNode widget,
    int? index,
  ) {
    // ------------------------------------------------------------------------
    // PARENTS MULTI-ENFANTS
    // ------------------------------------------------------------------------

    if (_isMultiChildType(
      parent.type,
    )) {
      final children =
          List<WidgetNode>.from(
        parent.children ??
            <WidgetNode>[],
      );

      _insertAtSafeIndex(
        children,
        widget,
        index,
      );

      final updatedParent =
          parent.copyWith(
        children: children,
      );

      return _TreeMutationResult(
        root: root.replaceNode(
          parent.id,
          updatedParent,
        ),
        changed: true,
      );
    }

    // ------------------------------------------------------------------------
    // PARENT À ENFANT UNIQUE
    // ------------------------------------------------------------------------

    final existingChild =
        parent.child;

    // Pas d'enfant -> insertion directe.
    if (existingChild == null) {
      final updatedParent =
          parent.copyWith(
        child: widget,
      );

      return _TreeMutationResult(
        root: root.replaceNode(
          parent.id,
          updatedParent,
        ),
        changed: true,
      );
    }

    // Enfant existant -> Column automatique.
    final children =
        <WidgetNode>[
      existingChild,
      widget,
    ];

    if (index != null &&
        index >= 0 &&
        index < children.length) {
      children.remove(widget);
      children.insert(
        index,
        widget,
      );
    }

    final column =
        WidgetNode.create(
      type: 'Column',
      properties:
          <String, dynamic>{},
      children: children,
    );

    final updatedParent =
        parent.copyWith(
      child: column,
    );

    return _TreeMutationResult(
      root: root.replaceNode(
        parent.id,
        updatedParent,
      ),
      changed: true,
    );
  }

  // ==========================================================================
  // INSERTION INDEX
  // ==========================================================================

  void _insertAtSafeIndex(
    List<WidgetNode> list,
    WidgetNode widget,
    int? index,
  ) {
    if (index == null ||
        index < 0 ||
        index > list.length) {
      list.add(widget);
      return;
    }

    list.insert(
      index,
      widget,
    );
  }

  // ==========================================================================
  // TYPES
  // ==========================================================================

  bool _canAcceptChildren(
    String type,
  ) {
    return _isMultiChildType(type) ||
        _isSingleChildType(type);
  }

  bool _isMultiChildType(
    String type,
  ) {
    const types =
        <String>{
      'Row',
      'Column',
      'Stack',
      'ListView',
      'GridView',
      'Wrap',
    };

    return types.contains(type);
  }

  bool _isSingleChildType(
    String type,
  ) {
    const types =
        <String>{
      'Container',
      'Center',
      'Align',
      'Padding',
      'SizedBox',
      'Card',
      'Expanded',
      'Flexible',
      'SafeArea',
      'SingleChildScrollView',
      'Visibility',
      'Opacity',
      'Scaffold',
    };

    return types.contains(type);
  }

  // ==========================================================================
  // RECHERCHE DE PARENT
  // ==========================================================================

  WidgetNode? _findParentNode(
    WidgetNode root,
    String childId,
  ) {
    if (root.child?.id ==
        childId) {
      return root;
    }

    for (final child
        in root.children ??
            <WidgetNode>[]) {
      if (child.id == childId) {
        return root;
      }

      final result =
          _findParentNode(
        child,
        childId,
      );

      if (result != null) {
        return result;
      }
    }

    if (root.child != null) {
      final result =
          _findParentNode(
        root.child!,
        childId,
      );

      if (result != null) {
        return result;
      }
    }

    return null;
  }

  // ==========================================================================
  // INDEX D'UN ENFANT
  // ==========================================================================

  int _indexOfChild(
    WidgetNode parent,
    String childId,
  ) {
    final children =
        parent.children;

    if (children != null) {
      for (int i = 0;
          i < children.length;
          i++) {
        if (children[i].id ==
            childId) {
          return i;
        }
      }
    }

    if (parent.child?.id ==
        childId) {
      return 0;
    }

    return -1;
  }

  // ==========================================================================
  // DESCENDANT
  // ==========================================================================

  bool _isDescendant(
    WidgetNode ancestor,
    String nodeId,
  ) {
    if (ancestor.id ==
        nodeId) {
      return true;
    }

    if (ancestor.child != null &&
        _isDescendant(
          ancestor.child!,
          nodeId,
        )) {
      return true;
    }

    for (final child
        in ancestor.children ??
            <WidgetNode>[]) {
      if (_isDescendant(
        child,
        nodeId,
      )) {
        return true;
      }
    }

    return false;
  }

  // ==========================================================================
  // CHERCHE UN ENFANT DIRECT
  // ==========================================================================

  WidgetNode? _findDirectChildByType(
    WidgetNode node,
    String type,
  ) {
    if (node.child?.type ==
        type) {
      return node.child;
    }

    for (final child
        in node.children ??
            <WidgetNode>[]) {
      if (child.type == type) {
        return child;
      }
    }

    return null;
  }

  WidgetNode? _findScaffoldBody(
    WidgetNode scaffold,
  ) {
    final children =
        scaffold.children;

    if (children != null) {
      for (final child
          in children) {
        if (child.type !=
            'AppBar') {
          return child;
        }
      }
    }

    if (scaffold.child != null &&
        scaffold.child!.type !=
            'AppBar') {
      return scaffold.child;
    }

    return null;
  }

  // ==========================================================================
  // VÉRIFICATION ID DUPLIQUÉ
  // ==========================================================================

  bool _containsDuplicateId(
    WidgetNode root,
    String id,
  ) {
    final matches =
        root.findById(id);

    return matches != null;
  }

  // ==========================================================================
  // PROJECT HELPERS
  // ==========================================================================

  PageModel? _getCurrentPage(
    ProjectModel project,
  ) {
    if (state.currentPageId.isEmpty) {
      if (project.pages.isNotEmpty) {
        return project.pages.first;
      }

      return null;
    }

    return project.getPageById(
      state.currentPageId,
    );
  }

  ProjectModel _replacePageInProject(
    ProjectModel project,
    PageModel updatedPage,
  ) {
    final updatedPages =
        project.pages.map(
      (page) {
        if (page.id ==
            updatedPage.id) {
          return updatedPage;
        }

        return page;
      },
    ).toList();

    return project.copyWith(
      pages: updatedPages,
    );
  }

  void _setProject(
    ProjectModel project, {
    String? selectedWidgetId,
    bool clearSelection = false,
  }) {
    ref
        .read(
          activeProjectProvider
              .notifier,
        )
        .state = project;

    if (clearSelection) {
      state = state.copyWith(
        clearSelectedWidgetId: true,
      );
      return;
    }

    if (selectedWidgetId !=
        null) {
      state = state.copyWith(
        selectedWidgetId:
            selectedWidgetId,
      );
    }
  }

  // ==========================================================================
  // RESTAURATION DE SÉLECTION
  // ==========================================================================

  void _restoreSelectionAfterProjectChange(
    ProjectModel project,
  ) {
    final selectedId =
        state.selectedWidgetId;

    if (selectedId == null) {
      return;
    }

    final page =
        _getCurrentPage(project);

    if (page?.rootWidget == null) {
      clearSelection();
      return;
    }

    final widget =
        page!.rootWidget!
            .findById(
      selectedId,
    );

    if (widget == null) {
      clearSelection();
    }
  }

  // ==========================================================================
  // VALIDATION DE L'ARBRE
  // ==========================================================================

  List<String> validateCurrentTree() {
    final project =
        ref.read(activeProjectProvider);

    if (project == null) {
      return const <String>[
        'Aucun projet actif.'
      ];
    }

    final page =
        _getCurrentPage(project);

    if (page == null) {
      return <String>[
        'Aucune page courante.'
      ];
    }

    if (page.rootWidget == null) {
      return <String>[
        'La page ne possède aucun widget racine.'
      ];
    }

    final errors =
        <String>[];

    final ids =
        <String>{};

    _validateNode(
      page.rootWidget!,
      ids,
      errors,
    );

    return errors;
  }

  void _validateNode(
    WidgetNode node,
    Set<String> ids,
    List<String> errors,
  ) {
    if (node.id.isEmpty) {
      errors.add(
        'Widget ${node.type} possède un ID vide.',
      );
    }

    if (!ids.add(node.id)) {
      errors.add(
        'ID dupliqué : ${node.id}',
      );
    }

    final hasChild =
        node.child != null;

    final hasChildren =
        node.children != null &&
            node.children!.isNotEmpty;

    if (hasChild &&
        hasChildren) {
      errors.add(
        'Le widget ${node.id} utilise simultanément child et children.',
      );
    }

    if (node.children != null) {
      for (final child
          in node.children!) {
        _validateNode(
          child,
          ids,
          errors,
        );
      }
    }

    if (node.child != null) {
      _validateNode(
        node.child!,
        ids,
        errors,
      );
    }
  }

  // ==========================================================================
  // OPÉRATIONS COMPOSÉES
  // ==========================================================================

  /// Supprime tous les enfants d'un widget.
  void clearChildren(
    String widgetId,
  ) {
    final project =
        ref.read(activeProjectProvider);

    if (project == null) {
      return;
    }

    final page =
        _getCurrentPage(project);

    if (page?.rootWidget == null) {
      return;
    }

    final root =
        page!.rootWidget!;

    final target =
        root.findById(widgetId);

    if (target == null) {
      return;
    }

    _pushUndo(project);

    final updated =
        target.copyWith(
      child: null,
      children:
          <WidgetNode>[],
    );

    final updatedRoot =
        root.replaceNode(
      widgetId,
      updated,
    );

    final updatedPage =
        page.copyWith(
      rootWidget:
          updatedRoot,
    );

    final updatedProject =
        _replacePageInProject(
      project,
      updatedPage,
    );

    _setProject(
      updatedProject,
      selectedWidgetId:
          widgetId,
    );
  }

  /// Définit plusieurs propriétés dans une seule transaction.
  void updateWidgetPropertiesTransaction(
    String widgetId,
    Map<String, dynamic> properties,
  ) {
    if (properties.isEmpty) {
      return;
    }

    beginTransaction();

    try {
      updateWidgetProperties(
        widgetId,
        properties,
      );
    } finally {
      endTransaction();
    }
  }

  // ==========================================================================
  // DÉPLACEMENT DE GROUPE
  // ==========================================================================

  void moveWidgets(
    List<String> widgetIds, {
    required String? newParentId,
    int? startIndex,
  }) {
    if (widgetIds.isEmpty) {
      return;
    }

    final project =
        ref.read(activeProjectProvider);

    if (project == null) {
      return;
    }

    final page =
        _getCurrentPage(project);

    if (page?.rootWidget == null) {
      return;
    }

    beginTransaction();

    try {
      int insertionIndex =
          startIndex ?? 0;

      for (final id
          in widgetIds) {
        moveWidget(
          id,
          newParentId:
              newParentId,
          index:
              insertionIndex,
        );

        insertionIndex++;
      }
    } finally {
      endTransaction();
    }
  }

  // ==========================================================================
  // RESET PAGE
  // ==========================================================================

  void resetCurrentPage() {
    final project =
        ref.read(activeProjectProvider);

    if (project == null) {
      return;
    }

    final page =
        _getCurrentPage(project);

    if (page == null) {
      return;
    }

    _pushUndo(project);

    final updatedPage =
        page.copyWith(
      rootWidget:
          _createSafeEmptyRoot(),
    );

    final updatedProject =
        _replacePageInProject(
      project,
      updatedPage,
    );

    _setProject(
      updatedProject,
      clearSelection: true,
    );
  }
}

/// ============================================================================
/// RÉSULTAT INTERNE DE MUTATION
/// ============================================================================

class _TreeMutationResult {
  final WidgetNode root;
  final bool changed;

  const _TreeMutationResult({
    required this.root,
    required this.changed,
  });
}

/// ============================================================================
/// PROVIDER
/// ============================================================================

final editorProvider =
    NotifierProvider<
        EditorNotifier,
        EditorState>(
  EditorNotifier.new,
);