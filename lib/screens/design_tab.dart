import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/page_model.dart';
import '../models/project_model.dart';
import '../models/widget_node.dart';
import '../providers/editor_provider.dart';
import '../providers/project_provider.dart';
import '../render_engine/json_widget_parser.dart';
import '../render_engine/render_context.dart';
import '../widgets/property_inspector.dart';

/// ============================================================================
/// DESIGN STUDIO
/// ============================================================================
///
/// Architecture :
///
/// Palette
///    │
///    │ Drag
///    ▼
/// CanvasDragLayer
///    │
///    ├── DropRegistry
///    ├── DropTarget calculation
///    ├── insertion index
///    ├── drag overlay
///    └── commit au DROP seulement
///             │
///             ▼
///       EditorNotifier
///
/// Le ProjectModel n'est JAMAIS modifié pendant le déplacement du doigt.
/// Il n'est modifié qu'au relâchement.
///
/// ============================================================================

class DesignTab extends ConsumerStatefulWidget {
  final ProjectModel project;

  /// Le parent EditorScreen possède souvent déjà une toolbar.
  ///
  /// false = empêche le doublon visible dans ta capture.
  /// true = cette page affiche sa propre toolbar.
  final bool showInternalToolbar;

  final VoidCallback? onBack;
  final VoidCallback? onPreview;
  final VoidCallback? onExport;
  final VoidCallback? onSave;

  const DesignTab({
    super.key,
    required this.project,
    this.showInternalToolbar = false,
    this.onBack,
    this.onPreview,
    this.onExport,
    this.onSave,
  });

  @override
  ConsumerState<DesignTab> createState() => _DesignTabState();
}

/// ============================================================================
/// DRAG DATA
/// ============================================================================

class _DesignDragData {
  final String type;

  /// null = nouveau widget de la palette.
  /// non-null = déplacement d'un widget existant.
  final String? existingWidgetId;

  const _DesignDragData({
    required this.type,
    this.existingWidgetId,
  });

  bool get isExisting =>
      existingWidgetId != null;
}

/// ============================================================================
/// WIDGET DE PALETTE
/// ============================================================================

class _WidgetDefinition {
  final String type;
  final IconData icon;
  final Color color;
  final WidgetNode Function() create;

  const _WidgetDefinition({
    required this.type,
    required this.icon,
    required this.color,
    required this.create,
  });
}

/// ============================================================================
/// DROP
/// ============================================================================

enum _DropMode {
  inside,
  before,
  after,
}

class _DropPreview {
  final String targetId;
  final String? parentId;
  final int index;
  final _DropMode mode;
  final Rect globalRect;
  final String axis;

  const _DropPreview({
    required this.targetId,
    required this.parentId,
    required this.index,
    required this.mode,
    required this.globalRect,
    required this.axis,
  });
}

/// ============================================================================
/// REGISTRY DES NŒUDS
/// ============================================================================
///
/// Chaque nœud enregistre son BuildContext.
/// Au début du drag, on prend une photographie des rectangles.
/// Pendant le déplacement, aucune recherche de RenderBox n'est effectuée.
///
/// Cela évite une énorme quantité de travail pendant les mouvements du doigt.
///

class _NodeRegistration {
  final WidgetNode node;
  final WidgetNode? parent;
  final int index;
  final BuildContext context;

  const _NodeRegistration({
    required this.node,
    required this.parent,
    required this.index,
    required this.context,
  });
}

class _DropRegistry {
  final Map<String, _NodeRegistration> _registrations =
      <String, _NodeRegistration>{};

  Map<String, Rect> _snapshot = <String, Rect>{};

  void register(
    String id,
    WidgetNode node,
    WidgetNode? parent,
    int index,
    BuildContext context,
  ) {
    _registrations[id] = _NodeRegistration(
      node: node,
      parent: parent,
      index: index,
      context: context,
    );
  }

  void unregister(String id) {
    _registrations.remove(id);
  }

  void snapshot({
    required Rect phoneRect,
  }) {
    final result = <String, Rect>{};

    for (final entry in _registrations.entries) {
      final renderObject =
          entry.value.context.findRenderObject();

      if (renderObject is! RenderBox ||
          !renderObject.hasSize) {
        continue;
      }

      final topLeft =
          renderObject.localToGlobal(
        Offset.zero,
      );

      final rect = topLeft & renderObject.size;

      if (rect.overlaps(phoneRect) ||
          phoneRect.contains(rect.center)) {
        result[entry.key] = rect;
      }
    }

    _snapshot = result;
  }

  _NodeRegistration? registration(
    String id,
  ) {
    return _registrations[id];
  }

  void clearSnapshot() {
    _snapshot = <String, Rect>{};
  }

  _DropPreview? hitTest({
    required Offset globalPosition,
    required WidgetNode root,
    required _DesignDragData data,
    required Rect phoneRect,
    required bool Function(WidgetNode) canHaveChildren,
    required bool Function(String) canHaveMultipleChildren,
  }) {
    if (!phoneRect.contains(globalPosition)) {
      return null;
    }

    final candidates =
        <MapEntry<String, Rect>>[];

    for (final entry in _snapshot.entries) {
      if (entry.value.contains(globalPosition)) {
        final registration =
            _registrations[entry.key];

        if (registration == null) {
          continue;
        }

        if (data.existingWidgetId != null) {
          final draggedId =
              data.existingWidgetId!;

          if (registration.node.id == draggedId) {
            continue;
          }

          final dragged =
              root.findById(draggedId);

          if (dragged != null &&
              _isDescendant(
                dragged,
                registration.node.id,
              )) {
            continue;
          }
        }

        candidates.add(entry);
      }
    }

    candidates.sort(
      (a, b) {
        final aa =
            a.value.width *
                a.value.height;
        final bb =
            b.value.width *
                b.value.height;

        return aa.compareTo(bb);
      },
    );

    // ================================================================
    // 1. Trouver le nœud le plus profond sous le doigt.
    // ================================================================

    if (candidates.isNotEmpty) {
      final selected =
          candidates.first;

      final registration =
          _registrations[selected.key]!;

      final node =
          registration.node;

      final parent =
          registration.parent;

      // Un conteneur sans enfant peut recevoir directement.
      if (canHaveChildren(node) &&
          !_hasVisibleChildren(node)) {
        return _insidePreview(
          node,
          selected.value,
        );
      }

      // Si c'est un conteneur et le doigt est
      // dans une zone libre de son rectangle.
      if (canHaveChildren(node) &&
          _isNearContainerBackground(
            node,
            selected.value,
            globalPosition,
          )) {
        return _insidePreview(
          node,
          selected.value,
        );
      }

      // ==============================================================
      // 2. Le nœud sous le doigt devient la cible d'insertion.
      // ==============================================================

      if (parent != null) {
        final axis =
            _axisForParent(
          parent,
        );

        final before =
            axis == 'horizontal'
                ? globalPosition.dx <
                    selected.value.center.dx
                : globalPosition.dy <
                    selected.value.center.dy;

        final baseIndex =
            registration.index;

        return _DropPreview(
          targetId: node.id,
          parentId: parent.id,
          index: before
              ? baseIndex
              : baseIndex + 1,
          mode: before
              ? _DropMode.before
              : _DropMode.after,
          globalRect:
              selected.value,
          axis: axis,
        );
      }

      // Root.
      if (canHaveChildren(node)) {
        return _insidePreview(
          node,
          selected.value,
        );
      }
    }

    // ================================================================
    // 3. Aucun enfant touché : déposer dans le root.
    // ================================================================

    final rootRegistration =
        _registrations[root.id];

    if (rootRegistration != null) {
      final rootRect =
          _snapshot[root.id];

      if (rootRect != null &&
          rootRect.contains(
            globalPosition,
          ) &&
          canHaveChildren(root)) {
        final count =
            _childrenCount(root);

        return _DropPreview(
          targetId: root.id,
          parentId: root.id,
          index: count,
          mode: _DropMode.inside,
          globalRect: rootRect,
          axis: _axisForParent(root),
        );
      }
    }

    return null;
  }

  _DropPreview _insidePreview(
    WidgetNode node,
    Rect rect,
  ) {
    return _DropPreview(
      targetId: node.id,
      parentId: node.id,
      index: _childrenCount(node),
      mode: _DropMode.inside,
      globalRect: rect,
      axis: _axisForParent(node),
    );
  }

  static bool _hasVisibleChildren(
    WidgetNode node,
  ) {
    return node.child != null ||
        (node.children != null &&
            node.children!.isNotEmpty);
  }

  static int _childrenCount(
    WidgetNode node,
  ) {
    if (node.children != null) {
      return node.children!.length;
    }

    if (node.child != null) {
      return 1;
    }

    return 0;
  }

  static String _axisForParent(
    WidgetNode node,
  ) {
    switch (node.type) {
      case 'Row':
        return 'horizontal';

      default:
        return 'vertical';
    }
  }

  static bool _isDescendant(
    WidgetNode ancestor,
    String targetId,
  ) {
    if (ancestor.id ==
        targetId) {
      return true;
    }

    if (ancestor.child != null &&
        _isDescendant(
          ancestor.child!,
          targetId,
        )) {
      return true;
    }

    for (final child
        in ancestor.children ??
            <WidgetNode>[]) {
      if (_isDescendant(
        child,
        targetId,
      )) {
        return true;
      }
    }

    return false;
  }

  static bool _isNearContainerBackground(
    WidgetNode node,
    Rect rect,
    Offset position,
  ) {
    const edge = 20.0;

    final inside =
        rect.contains(position);

    if (!inside) {
      return false;
    }

    if (node.child == null &&
        (node.children == null ||
            node.children!.isEmpty)) {
      return true;
    }

    return position.dx <
            rect.left + edge ||
        position.dx >
            rect.right - edge ||
        position.dy <
            rect.top + edge ||
        position.dy >
            rect.bottom - edge;
  }
}

/// ============================================================================
/// DESIGN STATE
/// ============================================================================

class _DesignTabState
    extends ConsumerState<DesignTab>
    with TickerProviderStateMixin {
  static const double _phoneWidth = 300;
  static const double _phoneHeight = 610;

  static const Color _background =
      Color(0xFF08080C);

  static const Color _panel =
      Color(0xFF111117);

  static const Color _panel2 =
      Color(0xFF171720);

  static const Color _tile =
      Color(0xFF1A1A24);

  static const Color _cyan =
      Color(0xFF00E5FF);

  final GlobalKey<ScaffoldState>
      _scaffoldKey =
      GlobalKey<ScaffoldState>();

  final TextEditingController
      _searchController =
      TextEditingController();

  final ScrollController
      _paletteScrollController =
      ScrollController();

  final Set<String>
      _expandedCategories =
      <String>{};

  late final AnimationController
      _inspectorAnimationController;

  late final Animation<double>
      _inspectorAnimation;

  late final Map<
          String,
          List<_WidgetDefinition>>
      _widgetCategories;

  String? _selectedNodeId;

  bool _inspectorVisible = false;

  double _inspectorDragOffset = 0;

  bool _showGrid = true;

  bool _showDropHints = true;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _widgetCategories =
        _createWidgetCatalog();

    _expandedCategories
        .addAll(
      _widgetCategories.keys,
    );

    _inspectorAnimationController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 180,
      ),
    );

    _inspectorAnimation =
        CurvedAnimation(
      parent:
          _inspectorAnimationController,
      curve:
          Curves.easeOutCubic,
    );

    _searchController.addListener(
      _onSearchChanged,
    );
  }

  void _onSearchChanged() {
    if (!mounted) return;

    final value =
        _searchController.text
            .trim()
            .toLowerCase();

    if (value == _searchQuery) {
      return;
    }

    setState(() {
      _searchQuery = value;
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(
      _onSearchChanged,
    );

    _searchController.dispose();
    _paletteScrollController.dispose();
    _inspectorAnimationController
        .dispose();

    super.dispose();
  }

  // ==========================================================================
  // PROJECT
  // ==========================================================================

  ProjectModel _currentProject() {
    return ref.read(
          activeProjectProvider,
        ) ??
        widget.project;
  }

  PageModel? _currentPage() {
    final project =
        _currentProject();

    final editor =
        ref.read(editorProvider);

    final pageId =
        editor.currentPageId;

    for (final page
        in project.pages) {
      if (page.id == pageId) {
        return page;
      }
    }

    if (project.pages.isNotEmpty) {
      return project.pages.first;
    }

    return null;
  }

  // ==========================================================================
  // SELECTION
  // ==========================================================================

  void _selectWidget(
    String id,
  ) {
    if (id.isEmpty) return;

    setState(() {
      _selectedNodeId = id;
      _inspectorVisible = true;
      _inspectorDragOffset = 0;
    });

    ref
        .read(editorProvider.notifier)
        .selectWidget(id);

    _inspectorAnimationController
        .forward();
  }

  void _clearSelection() {
    setState(() {
      _selectedNodeId = null;
      _inspectorVisible = false;
      _inspectorDragOffset = 0;
    });

    ref
        .read(editorProvider.notifier)
        .clearSelection();

    _inspectorAnimationController
        .reverse();
  }

  void _closeInspector() {
    setState(() {
      _inspectorVisible = false;
      _inspectorDragOffset = 0;
    });

    _inspectorAnimationController
        .reverse();
  }

  // ==========================================================================
  // WIDGET CATALOG
  // ==========================================================================

  Map<String, List<_WidgetDefinition>>
      _createWidgetCatalog() {
    return {
      'Structure': [
        _definition(
          'Container',
          Icons.crop_din,
          Colors.blueAccent,
          () => WidgetNode.create(
            type: 'Container',
            properties: {
              'color': '#FFFFFFFF',
              'padding': 8,
              'borderRadius': 8,
            },
            children: const [],
          ),
        ),
        _definition(
          'Column',
          Icons.view_column,
          Colors.indigoAccent,
          () => WidgetNode.create(
            type: 'Column',
            properties: {
              'mainAxisAlignment':
                  'start',
              'crossAxisAlignment':
                  'center',
              'mainAxisSize': 'max',
            },
            children: const [],
          ),
        ),
        _definition(
          'Row',
          Icons.table_rows,
          Colors.indigoAccent,
          () => WidgetNode.create(
            type: 'Row',
            properties: {
              'mainAxisAlignment':
                  'start',
              'crossAxisAlignment':
                  'center',
            },
            children: const [],
          ),
        ),
        _definition(
          'Stack',
          Icons.layers,
          Colors.deepPurpleAccent,
          () => WidgetNode.create(
            type: 'Stack',
            children: const [],
          ),
        ),
        _definition(
          'Center',
          Icons.center_focus_strong,
          Colors.cyanAccent,
          () => WidgetNode.create(
            type: 'Center',
            children: const [],
          ),
        ),
        _definition(
          'Align',
          Icons.open_with,
          Colors.tealAccent,
          () => WidgetNode.create(
            type: 'Align',
            properties: {
              'alignment': 'center',
            },
            children: const [],
          ),
        ),
        _definition(
          'Padding',
          Icons.space_bar,
          Colors.orangeAccent,
          () => WidgetNode.create(
            type: 'Padding',
            properties: {
              'padding': 12,
            },
            children: const [],
          ),
        ),
        _definition(
          'SizedBox',
          Icons.check_box_outline_blank,
          Colors.grey,
          () => WidgetNode.create(
            type: 'SizedBox',
            properties: {
              'width': 100,
              'height': 50,
            },
            children: const [],
          ),
        ),
      ],
      'Base': [
        _definition(
          'Text',
          Icons.text_fields,
          Colors.orangeAccent,
          () => WidgetNode.create(
            type: 'Text',
            properties: {
              'data': 'Texte',
              'fontSize': 16,
              'color': '#FF202020',
              'fontWeight': 'normal',
              'textAlign': 'left',
            },
          ),
        ),
        _definition(
          'Button',
          Icons.smart_button,
          Colors.greenAccent,
          () => WidgetNode.create(
            type: 'Button',
            properties: {
              'text': 'Bouton',
              'buttonType': 'elevated',
              'enabled': true,
            },
          ),
        ),
        _definition(
          'Icon',
          Icons.star,
          Colors.yellowAccent,
          () => WidgetNode.create(
            type: 'Icon',
            properties: {
              'icon': 'star',
              'size': 28,
              'color': '#FFFFD600',
            },
          ),
        ),
        _definition(
          'Image',
          Icons.image,
          Colors.purpleAccent,
          () => WidgetNode.create(
            type: 'Image',
            properties: {
              'src': '',
              'fit': 'cover',
              'width': 100,
              'height': 100,
            },
          ),
        ),
        _definition(
          'Card',
          Icons.credit_card,
          Colors.lightBlueAccent,
          () => WidgetNode.create(
            type: 'Card',
            properties: {
              'elevation': 2,
              'borderRadius': 12,
            },
            children: const [],
          ),
        ),
        _definition(
          'Divider',
          Icons.remove,
          Colors.white70,
          () => WidgetNode.create(
            type: 'Divider',
            properties: {
              'height': 1,
              'thickness': 1,
            },
          ),
        ),
      ],
      'Formulaires': [
        _definition(
          'TextField',
          Icons.input,
          Colors.pinkAccent,
          () => WidgetNode.create(
            type: 'TextField',
            properties: {
              'hintText': 'Saisir...',
              'labelText': 'Texte',
            },
          ),
        ),
        _definition(
          'Checkbox',
          Icons.check_box,
          Colors.lightGreenAccent,
          () => WidgetNode.create(
            type: 'Checkbox',
            properties: {
              'value': false,
            },
          ),
        ),
        _definition(
          'Switch',
          Icons.toggle_on,
          Colors.deepOrangeAccent,
          () => WidgetNode.create(
            type: 'Switch',
            properties: {
              'value': false,
            },
          ),
        ),
        _definition(
          'Slider',
          Icons.linear_scale,
          Colors.amberAccent,
          () => WidgetNode.create(
            type: 'Slider',
            properties: {
              'min': 0,
              'max': 100,
              'value': 50,
            },
          ),
        ),
      ],
      'Listes': [
        _definition(
          'ListView',
          Icons.format_list_bulleted,
          Colors.blueGrey,
          () => WidgetNode.create(
            type: 'ListView',
            properties: {
              'scrollDirection':
                  'vertical',
            },
            children: const [],
          ),
        ),
        _definition(
          'GridView',
          Icons.grid_view,
          Colors.deepPurpleAccent,
          () => WidgetNode.create(
            type: 'GridView',
            properties: {
              'crossAxisCount': 2,
            },
            children: const [],
          ),
        ),
        _definition(
          'ListTile',
          Icons.list_alt,
          Colors.lightBlueAccent,
          () => WidgetNode.create(
            type: 'ListTile',
            properties: {
              'title': 'Titre',
              'subtitle':
                  'Sous-titre',
              'leadingIcon':
                  'star',
              'trailingIcon':
                  'chevron_right',
            },
          ),
        ),
        _definition(
          'Wrap',
          Icons.view_comfy_alt,
          Colors.tealAccent,
          () => WidgetNode.create(
            type: 'Wrap',
            properties: {
              'spacing': 8,
              'runSpacing': 8,
            },
            children: const [],
          ),
        ),
      ],
      'Mise en page': [
        _definition(
          'Expanded',
          Icons.expand,
          Colors.cyan,
          () => WidgetNode.create(
            type: 'Expanded',
            properties: {
              'flex': 1,
            },
            children: const [],
          ),
        ),
        _definition(
          'Flexible',
          Icons.unfold_more,
          Colors.lightBlue,
          () => WidgetNode.create(
            type: 'Flexible',
            properties: {
              'flex': 1,
            },
            children: const [],
          ),
        ),
        _definition(
          'Spacer',
          Icons.space_bar,
          Colors.blueGrey,
          () => WidgetNode.create(
            type: 'Spacer',
            properties: {
              'flex': 1,
            },
          ),
        ),
        _definition(
          'SafeArea',
          Icons.security,
          Colors.greenAccent,
          () => WidgetNode.create(
            type: 'SafeArea',
            children: const [],
          ),
        ),
        _definition(
          'SingleChildScrollView',
          Icons.swap_vert,
          Colors.purpleAccent,
          () => WidgetNode.create(
            type:
                'SingleChildScrollView',
            children: const [],
          ),
        ),
      ],
      'Composants': [
        _definition(
          'Scaffold',
          Icons.web,
          Colors.tealAccent,
          () => WidgetNode.create(
            type: 'Scaffold',
            children: const [],
          ),
        ),
        _definition(
          'AppBar',
          Icons.web_asset,
          Colors.lightBlueAccent,
          () => WidgetNode.create(
            type: 'AppBar',
            properties: {
              'title': 'Titre',
            },
          ),
        ),
        _definition(
          'Visibility',
          Icons.visibility,
          Colors.orangeAccent,
          () => WidgetNode.create(
            type: 'Visibility',
            properties: {
              'visible': true,
            },
            children: const [],
          ),
        ),
        _definition(
          'Opacity',
          Icons.opacity,
          Colors.amberAccent,
          () => WidgetNode.create(
            type: 'Opacity',
            properties: {
              'opacity': 1.0,
            },
            children: const [],
          ),
        ),
      ],
    };
  }

  _WidgetDefinition _definition(
    String type,
    IconData icon,
    Color color,
    WidgetNode Function() create,
  ) {
    return _WidgetDefinition(
      type: type,
      icon: icon,
      color: color,
      create: create,
    );
  }

  WidgetNode? _createWidget(
    String type,
  ) {
    for (final list
        in _widgetCategories.values) {
      for (final definition
          in list) {
        if (definition.type ==
            type) {
          return definition.create();
        }
      }
    }

    return null;
  }

  // ==========================================================================
  // CHILDREN RULES
  // ==========================================================================

  bool _canHaveChildren(
    WidgetNode node,
  ) {
    const types = <String>{
      'Container',
      'Column',
      'Row',
      'Stack',
      'Center',
      'Align',
      'Padding',
      'SizedBox',
      'ListView',
      'GridView',
      'Wrap',
      'Scaffold',
      'Card',
      'Expanded',
      'Flexible',
      'SafeArea',
      'SingleChildScrollView',
      'Visibility',
      'Opacity',
    };

    return types.contains(
      node.type,
    );
  }

  bool _canHaveMultipleChildren(
    String type,
  ) {
    const types = <String>{
      'Column',
      'Row',
      'Stack',
      'ListView',
      'GridView',
      'Wrap',
      'Scaffold',
    };

    return types.contains(type);
  }

  // ==========================================================================
  // COMMIT DROP
  // ==========================================================================

  void _commitDrop(
    _DropPreview preview,
    _DesignDragData data,
    PageModel page,
  ) {
    if (data.existingWidgetId !=
        null) {
      ref
          .read(editorProvider.notifier)
          .moveWidget(
            data.existingWidgetId!,
            newParentId:
                preview.parentId,
            index: preview.index,
          );

      _selectWidget(
        data.existingWidgetId!,
      );

      return;
    }

    final newWidget =
        _createWidget(
      data.type,
    );

    if (newWidget == null) {
      _showSnack(
        'Widget non supporté : ${data.type}',
        error: true,
      );
      return;
    }

    ref
        .read(editorProvider.notifier)
        .addWidget(
          newWidget,
          parentId:
              preview.parentId,
          index:
              preview.index,
        );

    _selectWidget(
      newWidget.id,
    );
  }

  // ==========================================================================
  // DUPLICATION
  // ==========================================================================

  void _duplicateWidget(
    WidgetNode original,
  ) {
    final clone =
        _cloneNode(
      original,
    );

    if (clone == null) {
      _showSnack(
        'Duplication impossible',
        error: true,
      );
      return;
    }

    final root =
        _currentPage()?.rootWidget;

    if (root == null) {
      return;
    }

    final parent =
        _findParent(
      root,
      original.id,
    );

    if (parent == null) {
      _showSnack(
        'La racine ne peut pas être dupliquée ici.',
        error: true,
      );
      return;
    }

    final originalIndex =
        _indexOfChild(
      parent,
      original.id,
    );

    ref
        .read(editorProvider.notifier)
        .addWidget(
          clone,
          parentId:
              parent.id,
          index: originalIndex < 0
              ? null
              : originalIndex + 1,
        );

    _selectWidget(
      clone.id,
    );
  }

  WidgetNode? _cloneNode(
    WidgetNode original,
  ) {
    try {
      final clonedChildren =
          <WidgetNode>[];

      for (final child
          in original.children ??
              <WidgetNode>[]) {
        final cloned =
            _cloneNode(child);

        if (cloned != null) {
          clonedChildren.add(
            cloned,
          );
        }
      }

      WidgetNode? clonedChild;

      if (original.child !=
          null) {
        clonedChild =
            _cloneNode(
          original.child!,
        );
      }

      return WidgetNode.create(
        type: original.type,
        properties:
            Map<String, dynamic>.from(
          original.properties ??
              const <String, dynamic>{},
        ),
        child:
            clonedChild,
        children:
            clonedChildren,
      );
    } catch (_) {
      return null;
    }
  }

  WidgetNode? _findParent(
    WidgetNode root,
    String id,
  ) {
    if (root.child?.id == id) {
      return root;
    }

    for (final child
        in root.children ??
            <WidgetNode>[]) {
      if (child.id == id) {
        return root;
      }

      final result =
          _findParent(
        child,
        id,
      );

      if (result != null) {
        return result;
      }
    }

    if (root.child != null) {
      final result =
          _findParent(
        root.child!,
        id,
      );

      if (result != null) {
        return result;
      }
    }

    return null;
  }

  int _indexOfChild(
    WidgetNode parent,
    String id,
  ) {
    final children =
        parent.children;

    if (children != null) {
      for (int i = 0;
          i < children.length;
          i++) {
        if (children[i].id ==
            id) {
          return i;
        }
      }
    }

    if (parent.child?.id ==
        id) {
      return 0;
    }

    return -1;
  }

  // ==========================================================================
  // UNDO / REDO
  // ==========================================================================

  void _undo() {
    ref
        .read(editorProvider.notifier)
        .undo();
  }

  void _redo() {
    ref
        .read(editorProvider.notifier)
        .redo();
  }

  // ==========================================================================
  // SNACK
  // ==========================================================================

  void _showSnack(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration:
              const Duration(
            milliseconds: 1300,
          ),
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              error
                  ? const Color(
                      0xFFB3261E,
                    )
                  : const Color(
                      0xFF17171F,
                    ),
          content: Text(
            message,
          ),
        ),
      );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final project =
        ref.watch(
      activeProjectProvider,
    ) ??
            widget.project;

    final editor =
        ref.watch(
      editorProvider,
    );

    final selectedId =
        ref.watch(
      editorProvider.select(
        (state) =>
            state.selectedWidgetId,
      ),
    );

    final canUndo =
        ref.watch(
      editorProvider.select(
        (state) =>
            state.canUndo,
      ),
    );

    final canRedo =
        ref.watch(
      editorProvider.select(
        (state) =>
            state.canRedo,
      ),
    );

    final page =
        _resolvePage(
      project,
      editor.currentPageId,
    );

    if (page == null) {
      return const ColoredBox(
        color: _background,
        child: Center(
          child: Text(
            'Aucune page disponible.',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    final root =
        page.rootWidget;

    WidgetNode? selectedWidget;

    if (root != null &&
        selectedId != null) {
      selectedWidget =
          root.findById(
        selectedId,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor:
          _background,
      drawer:
          _buildSettingsDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.showInternalToolbar)
              _buildToolbar(
                canUndo:
                    canUndo,
                canRedo:
                    canRedo,
              ),

            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width:
                        _paletteWidth(
                      context,
                    ),
                    child:
                        _buildPalette(),
                  ),

                  Expanded(
                    child:
                        _DesignCanvas(
                      project: project,
                      page: page,
                      rootWidget: root,
                      selectedWidgetId:
                          selectedId,
                      showGrid:
                          _showGrid,
                      showDropHints:
                          _showDropHints,
                      canHaveChildren:
                          _canHaveChildren,
                      canHaveMultipleChildren:
                          _canHaveMultipleChildren,
                      createWidget:
                          _createWidget,
                      onSelect:
                          _selectWidget,
                      onClearSelection:
                          _clearSelection,
                      onDrop:
                          _commitDrop,
                      onDuplicate:
                          _duplicateWidget,
                      onDelete:
                          (node) {
                        ref
                            .read(
                              editorProvider
                                  .notifier,
                            )
                            .removeWidget(
                              node.id,
                            );

                        _clearSelection();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton:
          null,
    );
  }

  PageModel? _resolvePage(
    ProjectModel project,
    String pageId,
  ) {
    for (final page
        in project.pages) {
      if (page.id ==
          pageId) {
        return page;
      }
    }

    if (project.pages.isNotEmpty) {
      return project.pages.first;
    }

    return null;
  }

  // ==========================================================================
  // TOOLBAR
  // ==========================================================================

  Widget _buildToolbar({
    required bool canUndo,
    required bool canRedo,
  }) {
    return Container(
      height: 52,
      color:
          const Color(0xFF101015),
      child: Row(
        children: [
          IconButton(
            onPressed:
                widget.onBack ??
                    () {
                      Navigator.of(
                        context,
                      ).maybePop();
                    },
            icon: const Icon(
              Icons.arrow_back,
              color:
                  Colors.white70,
            ),
          ),
          IconButton(
            onPressed:
                canUndo
                    ? _undo
                    : null,
            icon: Icon(
              Icons.undo_rounded,
              color: canUndo
                  ? Colors.white70
                  : Colors.white24,
            ),
          ),
          IconButton(
            onPressed:
                canRedo
                    ? _redo
                    : null,
            icon: Icon(
              Icons.redo_rounded,
              color: canRedo
                  ? Colors.white70
                  : Colors.white24,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed:
                widget.onPreview ??
                    () => _showSnack(
                          'Prévisualisation',
                        ),
            icon: const Icon(
              Icons.play_arrow,
              color: _cyan,
            ),
          ),
          IconButton(
            onPressed:
                widget.onExport ??
                    () => _showSnack(
                          'Export',
                        ),
            icon: const Icon(
              Icons.download,
              color:
                  Colors.white70,
            ),
          ),
          IconButton(
            onPressed:
                widget.onSave ??
                    () => _showSnack(
                          'Enregistré',
                        ),
            icon: const Icon(
              Icons.save,
              color:
                  Colors.white70,
            ),
          ),
          IconButton(
            onPressed: () {
              _scaffoldKey.currentState
                  ?.openDrawer();
            },
            icon: const Icon(
              Icons.tune,
              color:
                  Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PALETTE
  // ==========================================================================

  double _paletteWidth(
    BuildContext context,
  ) {
    final width =
        MediaQuery.sizeOf(
      context,
    ).width;

    if (width < 600) {
      return 164;
    }

    if (width < 850) {
      return 180;
    }

    return 198;
  }

  Widget _buildPalette() {
    final filtered =
        <MapEntry<
            String,
            List<_WidgetDefinition>>>[];

    for (final entry
        in _widgetCategories.entries) {
      final list =
          entry.value
              .where(
                (item) =>
                    _searchQuery.isEmpty ||
                    item.type
                        .toLowerCase()
                        .contains(
                          _searchQuery,
                        ),
              )
              .toList();

      if (list.isNotEmpty) {
        filtered.add(
          MapEntry(
            entry.key,
            list,
          ),
        );
      }
    }

    return Container(
      color: _panel,
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(
              7,
            ),
            child:
                _buildSearchField(),
          ),
          Expanded(
            child:
                ListView(
              controller:
                  _paletteScrollController,
              padding:
                  const EdgeInsets.fromLTRB(
                7,
                0,
                7,
                70,
              ),
              children: [
                for (final entry
                    in filtered)
                  _buildCategory(
                    entry.key,
                    entry.value,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 36,
      decoration:
          BoxDecoration(
        color: _tile,
        borderRadius:
            BorderRadius.circular(
          9,
        ),
      ),
      child: TextField(
        controller:
            _searchController,
        style:
            const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
        decoration:
            InputDecoration(
          border:
              InputBorder.none,
          prefixIcon:
              const Icon(
            Icons.search,
            color:
                Colors.white38,
            size: 18,
          ),
          hintText:
              'Rechercher',
          hintStyle:
              const TextStyle(
            color:
                Colors.white30,
            fontSize: 11,
          ),
          suffixIcon:
              _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      splashRadius:
                          15,
                      onPressed:
                          () {
                        _searchController
                            .clear();
                      },
                      icon:
                          const Icon(
                        Icons.close,
                        size: 15,
                        color:
                            Colors.white38,
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildCategory(
    String category,
    List<_WidgetDefinition>
        widgets,
  ) {
    final expanded =
        _expandedCategories.contains(
      category,
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (expanded) {
                _expandedCategories
                    .remove(
                  category,
                );
              } else {
                _expandedCategories
                    .add(
                  category,
                );
              }
            });
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 2,
              vertical: 7,
            ),
            child: Row(
              children: [
                Icon(
                  expanded
                      ? Icons
                          .keyboard_arrow_down
                      : Icons
                          .keyboard_arrow_right,
                  color:
                      Colors.white38,
                  size: 16,
                ),
                Expanded(
                  child: Text(
                    category
                        .toUpperCase(),
                    style:
                        const TextStyle(
                      color:
                          Colors.white38,
                      fontWeight:
                          FontWeight.w800,
                      fontSize:
                          9.5,
                      letterSpacing:
                          1,
                    ),
                  ),
                ),
                Text(
                  '${widgets.length}',
                  style:
                      const TextStyle(
                    color:
                        Colors.white24,
                    fontSize:
                        9,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          GridView.builder(
            shrinkWrap:
                true,
            physics:
                const NeverScrollableScrollPhysics(),
            itemCount:
                widgets.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              childAspectRatio:
                  1.02,
            ),
            itemBuilder:
                (context, index) {
              return _buildPaletteItem(
                widgets[index],
              );
            },
          ),
        const SizedBox(
          height: 4,
        ),
      ],
    );
  }

  Widget _buildPaletteItem(
    _WidgetDefinition item,
  ) {
    final child =
        Container(
      decoration:
          BoxDecoration(
        color: _tile,
        borderRadius:
            BorderRadius.circular(
          8,
        ),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment
                .center,
        children: [
          Icon(
            item.icon,
            color:
                item.color,
            size: 20,
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            item.type,
            maxLines: 1,
            overflow:
                TextOverflow
                    .ellipsis,
            style:
                const TextStyle(
              color:
                  Colors.white70,
              fontWeight:
                  FontWeight.w600,
              fontSize:
                  9,
            ),
          ),
        ],
      ),
    );

    return Draggable<
        _DesignDragData>(
      data:
          _DesignDragData(
        type:
            item.type,
      ),
      maxSimultaneousDrags:
          1,
      feedback:
          Material(
        color:
            Colors.transparent,
        child:
            _buildDragFeedback(
          item.type,
          item.icon,
          item.color,
        ),
      ),
      childWhenDragging:
          Opacity(
        opacity:
            0.22,
        child:
            child,
      ),
      child:
          child,
    );
  }

  Widget _buildDragFeedback(
    String title,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 62,
      height: 62,
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFF242430,
        ),
        borderRadius:
            BorderRadius.circular(
          11,
        ),
        border:
            Border.all(
          color:
              _cyan,
          width: 1.5,
        ),
        boxShadow:
            const [
          BoxShadow(
            color:
                Colors.black54,
            blurRadius:
                16,
          ),
        ],
      ),
      child:
          Column(
        mainAxisAlignment:
            MainAxisAlignment
                .center,
        children: [
          Icon(
            icon,
            color:
                color,
            size: 24,
          ),
          const SizedBox(
            height: 2,
          ),
          Text(
            title,
            maxLines:
                1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontSize:
                  7.5,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SETTINGS
  // ==========================================================================

  Widget _buildSettingsDrawer() {
    return Drawer(
      backgroundColor:
          _panel,
      child:
          SafeArea(
        child:
            Column(
          children: [
            Container(
              padding:
                  const EdgeInsets.all(
                18,
              ),
              color:
                  _panel2,
              child:
                  const Row(
                children: [
                  Icon(
                    Icons.tune,
                    color:
                        _cyan,
                    size: 32,
                  ),
                  SizedBox(
                    width: 12,
                  ),
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        'Canvas',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              18,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                      SizedBox(
                        height: 3,
                      ),
                      Text(
                        'Configuration',
                        style:
                            TextStyle(
                          color:
                              Colors.white38,
                          fontSize:
                              11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SwitchListTile(
              value:
                  _showGrid,
              onChanged:
                  (value) {
                setState(
                  () {
                    _showGrid =
                        value;
                  },
                );
              },
              secondary:
                  const Icon(
                Icons.grid_on,
                color:
                    Colors.white70,
              ),
              title:
                  const Text(
                'Grille',
                style:
                    TextStyle(
                  color:
                      Colors.white,
                ),
              ),
            ),
            SwitchListTile(
              value:
                  _showDropHints,
              onChanged:
                  (value) {
                setState(
                  () {
                    _showDropHints =
                        value;
                  },
                );
              },
              secondary:
                  const Icon(
                Icons.drag_indicator,
                color:
                    Colors.white70,
              ),
              title:
                  const Text(
                'Zones de dépôt',
                style:
                    TextStyle(
                  color:
                      Colors.white,
                ),
              ),
            ),
            ListTile(
              leading:
                  const Icon(
                Icons.refresh,
                color:
                    Colors.redAccent,
              ),
              title:
                  const Text(
                'Réinitialiser la page',
                style:
                    TextStyle(
                  color:
                      Colors.redAccent,
                ),
              ),
              onTap:
                  () {
                ref
                    .read(
                      editorProvider
                          .notifier,
                    )
                    .resetCurrentPage();

                _clearSelection();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// CANVAS COMPLET
/// ============================================================================

class _DesignCanvas
    extends StatefulWidget {
  final ProjectModel project;
  final PageModel page;
  final WidgetNode? rootWidget;
  final String? selectedWidgetId;
  final bool showGrid;
  final bool showDropHints;

  final bool Function(
    WidgetNode node,
  ) canHaveChildren;

  final bool Function(
    String type,
  ) canHaveMultipleChildren;

  final WidgetNode? Function(
    String type,
  ) createWidget;

  final void Function(
    String id,
  ) onSelect;

  final VoidCallback
      onClearSelection;

  final void Function(
    _DropPreview preview,
    _DesignDragData data,
    PageModel page,
  ) onDrop;

  final void Function(
    WidgetNode node,
  ) onDuplicate;

  final void Function(
    WidgetNode node,
  ) onDelete;

  const _DesignCanvas({
    required this.project,
    required this.page,
    required this.rootWidget,
    required this.selectedWidgetId,
    required this.showGrid,
    required this.showDropHints,
    required this.canHaveChildren,
    required this.canHaveMultipleChildren,
    required this.createWidget,
    required this.onSelect,
    required this.onClearSelection,
    required this.onDrop,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  State<_DesignCanvas> createState() =>
      _DesignCanvasState();
}

class _DesignCanvasState
    extends State<_DesignCanvas> {
static const Color _cyan = Color(0xFF00E5FF);
  final _DropRegistry _registry =
      _DropRegistry();

  final ValueNotifier<
      _DropPreview?> _dropPreview =
      ValueNotifier<_DropPreview?>(
    null,
  );

  final GlobalKey _canvasKey =
      GlobalKey();

  final GlobalKey _phoneKey =
      GlobalKey();

  double _zoom = 0.82;

  _DesignDragData? _activeDrag;

  bool _snapshotTaken = false;

  @override
  void dispose() {
    _dropPreview.dispose();
    super.dispose();
  }

  // ==========================================================================
  // ZOOM
  // ==========================================================================

  void _zoomIn() {
    setState(() {
      _zoom =
          (_zoom + 0.08)
              .clamp(
        0.40,
        1.30,
      );
    });
  }

  void _zoomOut() {
    setState(() {
      _zoom =
          (_zoom - 0.08)
              .clamp(
        0.40,
        1.30,
      );
    });
  }

  void _zoomReset() {
    final fitted =
        _fitZoom();

    setState(() {
      _zoom =
          fitted;
    });
  }

  double _fitZoom() {
    final renderBox =
        _canvasKey.currentContext
            ?.findRenderObject();

    if (renderBox
        is! RenderBox) {
      return 0.70;
    }

    final size =
        renderBox.size;

    final horizontal =
        (size.width - 42) /
            300;

    final vertical =
        (size.height - 42) /
            610;

    return horizontal
        .clamp(
          0.40,
          1.15,
        )
        .clamp(
          0.40,
          vertical.clamp(
            0.40,
            1.15,
          ),
        );
  }

  // ==========================================================================
  // PHONE RECT
  // ==========================================================================

  Rect? _phoneRectGlobal() {
    final renderObject =
        _phoneKey.currentContext
            ?.findRenderObject();

    if (renderObject
        is! RenderBox ||
        !renderObject.hasSize) {
      return null;
    }

    final topLeft =
        renderObject.localToGlobal(
      Offset.zero,
    );

    return topLeft &
        renderObject.size;
  }

  // ==========================================================================
  // DRAG
  // ==========================================================================

  void _onDragMove(
    _DesignDragData data,
    Offset offset,
  ) {
    final root =
        widget.rootWidget;

    if (root == null) {
      return;
    }

    if (!_snapshotTaken ||
        _activeDrag?.type !=
            data.type ||
        _activeDrag?.existingWidgetId !=
            data.existingWidgetId) {
      final phoneRect =
          _phoneRectGlobal();

      if (phoneRect ==
          null) {
        return;
      }

      _registry.snapshot(
        phoneRect:
            phoneRect,
      );

      _activeDrag =
          data;

      _snapshotTaken =
          true;
    }

    final phoneRect =
        _phoneRectGlobal();

    if (phoneRect ==
        null) {
      return;
    }

    final preview =
        _registry.hitTest(
      globalPosition:
          offset,
      root: root,
      data: data,
      phoneRect:
          phoneRect,
      canHaveChildren:
          widget
              .canHaveChildren,
      canHaveMultipleChildren:
          widget
              .canHaveMultipleChildren,
    );

    _dropPreview.value =
        preview;
  }

  void _clearDrag() {
    _snapshotTaken =
        false;
    _activeDrag =
        null;
    _registry
        .clearSnapshot();
    _dropPreview.value =
        null;
  }

  void _onAccept(
    _DesignDragData data,
  ) {
    final preview =
        _dropPreview.value;

    if (preview != null) {
      widget.onDrop(
        preview,
        data,
        widget.page,
      );
    }

    _clearDrag();
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      key: _canvasKey,
      color:
          const Color(
        0xFF08080C,
      ),
      child:
          DragTarget<_DesignDragData>(
        onWillAcceptWithDetails:
            (details) {
          return true;
        },
        onMove:
            (details) {
          _onDragMove(
            details.data,
            details.offset,
          );
        },
        onLeave:
            (_) {
          _dropPreview.value =
              null;
        },
        onAcceptWithDetails:
            (details) {
          _onAccept(
            details.data,
          );
        },
        builder:
            (
          context,
          candidateData,
          rejectedData,
        ) {
          return Stack(
            fit:
                StackFit.expand,
            children: [
              if (widget.showGrid)
                const Positioned.fill(
                  child:
                      _GridBackground(),
                ),

              Center(
                child:
                    RepaintBoundary(
                  child:
                      _buildPhone(
                    context,
                  ),
                ),
              ),

              ValueListenableBuilder<
                  _DropPreview?>(
                valueListenable:
                    _dropPreview,
                builder:
                    (
                  context,
                  preview,
                  child,
                ) {
                  if (!widget
                          .showDropHints ||
                      preview ==
                          null) {
                    return const SizedBox.shrink();
                  }

                  return _buildDropIndicator(
                    context,
                    preview,
                  );
                },
              ),

              Positioned(
                right: 8,
                bottom:
                    14,
                child:
                    _buildZoomControls(),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================================================
  // PHONE
  // ==========================================================================

  Widget _buildPhone(
    BuildContext context,
  ) {
    final phone =
        Container(
      width: 300,
      height: 610,
      decoration:
          BoxDecoration(
        color:
            Colors.black,
        border:
            Border.all(
          color:
              const Color(
            0xFF282833,
          ),
          width:
              8,
        ),
        borderRadius:
            BorderRadius.circular(
          34,
        ),
        boxShadow:
            const [
          BoxShadow(
            color:
                Colors.black54,
            blurRadius:
                28,
            spreadRadius:
                2,
          ),
        ],
      ),
      child:
          ClipRRect(
        borderRadius:
            BorderRadius.circular(
          27,
        ),
        child:
            Column(
          children: [
            _buildPhoneStatusBar(),

            Expanded(
              child:
                  ColoredBox(
                color:
                    Colors.white,
                child:
                    widget.rootWidget ==
                            null
                        ? _buildEmptyPhone()
                        : _EditableNode(
                            node:
                                widget.rootWidget!,
                            parent:
                                null,
                            index:
                                0,
                            selectedId:
                                widget.selectedWidgetId,
                            registry:
                                _registry,
                            onSelect:
                                widget.onSelect,
                            onDuplicate:
                                widget.onDuplicate,
                            onDelete:
                                widget.onDelete,
                            root:
                                widget.rootWidget!,
                            canHaveChildren:
                                widget
                                    .canHaveChildren,
                            project:
                                widget.project,
                          ),
              ),
            ),
          ],
        ),
      ),
    );

    return SizedBox(
      key: _phoneKey,
      width:
          300 * _zoom,
      height:
          610 * _zoom,
      child:
          FittedBox(
        fit:
            BoxFit.contain,
        child:
            SizedBox(
          width:
              300,
          height:
              610,
          child:
              phone,
        ),
      ),
    );
  }

  Widget _buildPhoneStatusBar() {
    // UNE SEULE status bar dans le téléphone.
    return Container(
      height: 28,
      color:
          const Color(
        0xFF101015,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 13,
      ),
      child:
          Row(
        children: [
          const Text(
            '13:37',
            style:
                TextStyle(
              color:
                  Colors.white,
              fontSize:
                  10,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            width:
                58,
            height:
                13,
            decoration:
                BoxDecoration(
              color:
                  Colors.black,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
          ),
          const Spacer(),
          const Icon(
            Icons.signal_cellular_4_bar,
            size:
                11,
            color:
                Colors.white,
          ),
          const SizedBox(
            width:
                4,
          ),
          const Icon(
            Icons.wifi,
            size:
                11,
            color:
                Colors.white,
          ),
          const SizedBox(
            width:
                4,
          ),
          const Icon(
            Icons.battery_full,
            size:
                11,
            color:
                Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPhone() {
    return Center(
      child:
          Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          const Icon(
            Icons.smartphone,
            color:
                Colors.black26,
            size:
                42,
          ),
          const SizedBox(
            height:
                9,
          ),
          const Text(
            'Glissez un widget ici',
            style:
                TextStyle(
              color:
                  Colors.black38,
              fontSize:
                  12,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // DROP INDICATOR
  // ==========================================================================

  Widget _buildDropIndicator(
    BuildContext context,
    _DropPreview preview,
  ) {
    final canvasBox =
        _canvasKey.currentContext
            ?.findRenderObject();

    if (canvasBox
        is! RenderBox) {
      return const SizedBox.shrink();
    }

    final topLeft =
        canvasBox.globalToLocal(
      preview.globalRect.topLeft,
    );

    final rect = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      preview.globalRect.width,
      preview.globalRect.height,
    );

    if (preview.mode ==
        _DropMode.inside) {
      return Positioned(
        left:
            rect.left,
        top:
            rect.top,
        width:
            rect.width,
        height:
            rect.height,
        child:
            IgnorePointer(
          child:
              Container(
            decoration:
                BoxDecoration(
              border:
                  Border.all(
                color:
                    _cyan,
                width:
                    2,
              ),
              color:
                  _cyan.withOpacity(
                0.06,
              ),
              borderRadius:
                  BorderRadius.circular(
                5,
              ),
            ),
          ),
        ),
      );
    }

    if (preview.axis ==
        'horizontal') {
      final x =
          preview.mode ==
                  _DropMode.before
              ? rect.left
              : rect.right;

      return Positioned(
        left:
            x - 1.5,
        top:
            rect.top - 4,
        height:
            rect.height + 8,
        width:
            3,
        child:
            IgnorePointer(
          child:
              DecoratedBox(
            decoration:
                BoxDecoration(
              color:
                  _cyan,
              borderRadius:
                  BorderRadius.circular(
                3,
              ),
              boxShadow:
                  const [
                BoxShadow(
                  color:
                      _cyan,
                  blurRadius:
                      8,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final y =
        preview.mode ==
                _DropMode.before
            ? rect.top
            : rect.bottom;

    return Positioned(
      left:
          rect.left - 4,
      top:
          y - 1.5,
      width:
          rect.width + 8,
      height:
          3,
      child:
          IgnorePointer(
        child:
            DecoratedBox(
          decoration:
              BoxDecoration(
            color:
                _cyan,
            borderRadius:
                BorderRadius.circular(
              3,
            ),
            boxShadow:
                const [
              BoxShadow(
                color:
                    _cyan,
                blurRadius:
                    8,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // ZOOM
  // ==========================================================================

  Widget _buildZoomControls() {
    return Material(
      color:
          Colors.transparent,
      child:
          Container(
        padding:
            const EdgeInsets.all(
          4,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.black54,
          borderRadius:
              BorderRadius.circular(
            26,
          ),
        ),
        child:
            Column(
          children: [
            _zoomButton(
              Icons.add,
              _zoomIn,
            ),
            _zoomButton(
              Icons.remove,
              _zoomOut,
            ),
            _zoomButton(
              Icons.fit_screen,
              _zoomReset,
            ),
          ],
        ),
      ),
    );
  }

  Widget _zoomButton(
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap:
          onTap,
      borderRadius:
          BorderRadius.circular(
        24,
      ),
      child:
          SizedBox(
        width:
            43,
        height:
            43,
        child:
            Icon(
          icon,
          color:
              Colors.white,
          size:
              20,
        ),
      ),
    );
  }
}

/// ============================================================================
/// EDITABLE NODE
/// ============================================================================

class _EditableNode
    extends StatefulWidget {
  final WidgetNode node;
  final WidgetNode? parent;
  final int index;
  final String? selectedId;
  final _DropRegistry registry;
  final ValueChanged<String> onSelect;
  final ValueChanged<WidgetNode> onDuplicate;
  final ValueChanged<WidgetNode> onDelete;
  final WidgetNode root;
  final bool Function(WidgetNode) canHaveChildren;
  final ProjectModel project;

  const _EditableNode({
    required this.node,
    required this.parent,
    required this.index,
    required this.selectedId,
    required this.registry,
    required this.onSelect,
    required this.onDuplicate,
    required this.onDelete,
    required this.root,
    required this.canHaveChildren,
    required this.project,
  });

  @override
  State<_EditableNode> createState() =>
      _EditableNodeState();
}

class _EditableNodeState
    extends State<_EditableNode> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        widget.registry.register(
          widget.node.id,
          widget.node,
          widget.parent,
          widget.index,
          context,
        );
      },
    );
  }

  @override
  void didUpdateWidget(
    covariant _EditableNode oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.node.id !=
        widget.node.id) {
      widget.registry.unregister(
        oldWidget.node.id,
      );
    }

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!mounted) return;

        widget.registry.register(
          widget.node.id,
          widget.node,
          widget.parent,
          widget.index,
          context,
        );
      },
    );
  }

  @override
  void dispose() {
    widget.registry.unregister(
      widget.node.id,
    );

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final selected =
        widget.selectedId ==
            widget.node.id;

    final child =
        _buildNode();

    Widget result =
        GestureDetector(
      behavior:
          HitTestBehavior.opaque,
      onTap:
          () {
        widget.onSelect(
          widget.node.id,
        );
      },
      child:
          selected
              ? _selectionOverlay(
                  child,
                )
              : child,
    );

    // Root non draggable.
    if (widget.parent !=
        null) {
      result =
          LongPressDraggable<
              _DesignDragData>(
        data:
            _DesignDragData(
          type:
              widget.node.type,
          existingWidgetId:
              widget.node.id,
        ),
        maxSimultaneousDrags:
            1,
        feedback:
            Material(
          color:
              Colors.transparent,
          child:
              _buildExistingDragFeedback(
            widget.node.type,
          ),
        ),
        childWhenDragging:
            Opacity(
          opacity:
              0.25,
          child:
              result,
        ),
        child:
            result,
      );
    }

    return result;
  }

  Widget _selectionOverlay(
    Widget child,
  ) {
    return Stack(
      clipBehavior:
          Clip.none,
      children: [
        child,
        Positioned.fill(
          child:
              IgnorePointer(
            child:
                DecoratedBox(
              decoration:
                  BoxDecoration(
                border:
                    Border.all(
                  color:
                      const Color(
                    0xFF00E5FF,
                  ),
                  width:
                      1.5,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left:
              0,
          top:
              0,
          child:
              IgnorePointer(
            child:
                Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal:
                    5,
                vertical:
                    2,
              ),
              decoration:
                  const BoxDecoration(
                color:
                    Color(
                  0xFF00BCD4,
                ),
                borderRadius:
                    BorderRadius.only(
                  bottomRight:
                      Radius.circular(
                    5,
                  ),
                ),
              ),
              child:
                  Text(
                widget.node.type,
                style:
                    const TextStyle(
                  color:
                      Colors.black,
                  fontSize:
                      8,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExistingDragFeedback(
    String type,
  ) {
    return Container(
      width:
          90,
      height:
          48,
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            10,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFF20202A,
        ),
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFF00E5FF,
          ),
        ),
      ),
      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          const Icon(
            Icons.drag_indicator,
            color:
                Colors.cyanAccent,
            size:
                18,
          ),
          const SizedBox(
            width:
                5,
          ),
          Flexible(
            child:
                Text(
              type,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize:
                    10,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNode() {
    final p =
        Map<String, dynamic>.from(
      widget.node.properties ??
          const <String, dynamic>{},
    );

    final children =
        <Widget>[
      for (
        int i = 0;
        i <
            (widget.node.children
                    ?.length ??
                0);
        i++
      )
        _EditableNode(
          node:
              widget.node.children![
                  i],
          parent:
              widget.node,
          index:
              i,
          selectedId:
              widget.selectedId,
          registry:
              widget.registry,
          onSelect:
              widget.onSelect,
          onDuplicate:
              widget.onDuplicate,
          onDelete:
              widget.onDelete,
          root:
              widget.root,
          canHaveChildren:
              widget.canHaveChildren,
          project:
              widget.project,
        ),
    ];

    final parser =
        JsonWidgetParser(
      context:
          RenderContext(
        project:
            widget.project,
        variables:
            const <
                String,
                dynamic>{},
      ),
    );

    switch (widget.node.type) {
      case 'Container':
        return Container(
          width:
              _double(
            p['width'],
          ),
          height:
              _double(
            p['height'],
          ),
          padding:
              _padding(
            p['padding'],
          ),
          margin:
              _padding(
            p['margin'],
          ),
          alignment:
              _alignment(
            p['alignment'],
          ),
          decoration:
              BoxDecoration(
            color:
                _color(
              p['color'],
              fallback:
                  Colors.transparent,
            ),
            borderRadius:
                BorderRadius.circular(
              _double(
                    p['borderRadius'],
                  ) ??
                  0,
            ),
          ),
          child:
              _single(
            children,
            widget.node.child,
          ),
        );

      case 'Column':
        return Column(
          mainAxisSize:
              p['mainAxisSize'] ==
                      'min'
                  ? MainAxisSize.min
                  : MainAxisSize.max,
          mainAxisAlignment:
              _mainAxis(
            p['mainAxisAlignment'],
          ),
          crossAxisAlignment:
              _crossAxis(
            p['crossAxisAlignment'],
          ),
          children:
              children,
        );

      case 'Row':
        return Row(
          mainAxisSize:
              p['mainAxisSize'] ==
                      'min'
                  ? MainAxisSize.min
                  : MainAxisSize.max,
          mainAxisAlignment:
              _mainAxis(
            p['mainAxisAlignment'],
          ),
          crossAxisAlignment:
              _crossAxis(
            p['crossAxisAlignment'],
          ),
          children:
              children,
        );

      case 'Stack':
        return Stack(
          clipBehavior:
              Clip.none,
          children:
              children,
        );

      case 'Center':
        return Center(
          child:
              _single(
            children,
            widget.node.child,
          ),
        );

      case 'Align':
        return Align(
          alignment:
              _alignment(
            p['alignment'],
          ),
          child:
              _single(
            children,
            widget.node.child,
          ),
        );

      case 'Padding':
        return Padding(
          padding:
              _padding(
            p['padding'],
            fallback:
                const EdgeInsets.all(
              8,
            ),
          ),
          child:
              _single(
            children,
            widget.node.child,
          ),
        );

      case 'SizedBox':
        return SizedBox(
          width:
              _double(
            p['width'],
          ),
          height:
              _double(
            p['height'],
          ),
          child:
              _single(
            children,
            widget.node.child,
          ),
        );

      case 'Expanded':
        return Expanded(
          flex:
              _integer(
            p['flex'],
            1,
          ),
          child:
              _single(
            children,
            widget.node.child,
          ),
        );

      case 'Flexible':
        return Flexible(
          flex:
              _integer(
            p['flex'],
            1,
          ),
          child:
              _single(
            children,
            widget.node.child,
          ),
        );

      case 'Spacer':
        return Spacer(
          flex:
              _integer(
            p['flex'],
            1,
          ),
        );

      case 'Text':
        return Text(
          _string(
            p['data'],
            'Texte',
          ),
          textAlign:
              _textAlign(
            p['textAlign'],
          ),
          maxLines:
              _integerNullable(
            p['maxLines'],
          ),
          overflow:
              TextOverflow.clip,
          style:
              TextStyle(
            fontSize:
                _double(
                  p['fontSize'],
                ) ??
                    16,
            fontWeight:
                _fontWeight(
              p['fontWeight'],
            ),
            color:
                _color(
              p['color'],
              fallback:
                  Colors.black,
            ),
          ),
        );

      case 'Button':
      case 'ElevatedButton':
      case 'TextButton':
      case 'OutlinedButton':
        return _buildButton(
          p,
        );

      case 'Icon':
        return Icon(
          _icon(
            _string(
              p['icon'],
              'star',
            ),
          ),
          size:
              _double(
                    p['size'],
                  ) ??
                  28,
          color:
              _color(
            p['color'],
            fallback:
                Colors.amber,
          ),
        );

      case 'Image':
        return _buildImage(
          p,
        );

      case 'TextField':
        return const IgnorePointer(
          child:
              TextField(
            decoration:
                InputDecoration(
              border:
                  OutlineInputBorder(),
              hintText:
                  'Saisir...',
            ),
          ),
        );

      case 'Checkbox':
        return IgnorePointer(
          child:
              Checkbox(
            value:
                p['value'] ==
                    true,
            onChanged:
                (_) {},
          ),
        );

      case 'Switch':
        return IgnorePointer(
          child:
              Switch(
            value:
                p['value'] ==
                    true,
            onChanged:
                (_) {},
          ),
        );

      case 'Slider':
        final min =
            _double(
                  p['min'],
                ) ??
                0;
        final max =
            _double(
                  p['max'],
                ) ??
                100;
        final value =
            ((_double(
                      p['value'],
                    ) ??
                    50)
                .clamp(
              min,
              max,
            ));

        return IgnorePointer(
          child:
              Slider(
            min:
                min,
            max:
                max,
            value:
                value,
            onChanged:
                (_) {},
          ),
        );

      case 'ListView':
        return ListView(
          physics:
              const NeverScrollableScrollPhysics(),
          children:
              children,
        );

      case 'GridView':
        return GridView.count(
          physics:
              const NeverScrollableScrollPhysics(),
          shrinkWrap:
              true,
          crossAxisCount:
              _integer(
            p['crossAxisCount'],
            2,
          ).clamp(
            1,
            6,
          ),
          children:
              children,
        );

      case 'ListTile':
        return ListTile(
          leading:
              Icon(
            _icon(
              _string(
                p['leadingIcon'],
                'star',
              ),
            ),
          ),
          title:
              Text(
            _string(
              p['title'],
              'Titre',
            ),
          ),
          subtitle:
              Text(
            _string(
              p['subtitle'],
              'Sous-titre',
            ),
          ),
          trailing:
              Icon(
            _icon(
              _string(
                p['trailingIcon'],
                'chevron_right',
              ),
            ),
          ),
        );

      case 'Wrap':
        return Wrap(
          spacing:
              _double(
                    p['spacing'],
                  ) ??
                  8,
          runSpacing:
              _double(
                    p['runSpacing'],
                  ) ??
                  8,
          children:
              children,
        );

      case 'SafeArea':
        return SafeArea(
          child:
              _single(
            children,
            widget.node.child,
          ),
        );

      case 'SingleChildScrollView':
        return SingleChildScrollView(
          physics:
              const NeverScrollableScrollPhysics(),
          child:
              _single(
            children,
            widget.node.child,
          ),
        );

      case 'Card':
        return Card(
          margin:
              const EdgeInsets.all(
            5,
          ),
          elevation:
              _double(
                    p['elevation'],
                  ) ??
                  1,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              _double(
                    p['borderRadius'],
                  ) ??
                  10,
            ),
          ),
          child:
              _single(
            children,
            widget.node.child,
          ),
        );

      case 'Divider':
        return Divider(
          height:
              _double(
                    p['height'],
                  ) ??
                  1,
          thickness:
              _double(
                    p['thickness'],
                  ) ??
                  1,
        );

      case 'Visibility':
        return Visibility(
          visible:
              p['visible'] !=
                  false,
          child:
              _single(
            children,
            widget.node.child,
          ),
        );

      case 'Opacity':
        return Opacity(
          opacity:
              ((_double(
                        p['opacity'],
                      ) ??
                      1)
                  .clamp(
                0,
                1,
              )),
          child:
              _single(
            children,
            widget.node.child,
          ),
        );

      case 'Scaffold':
        return Container(
          color:
              _color(
                p['backgroundColor'],
                fallback:
                    Colors.white,
              ),
          child:
              _single(
            children,
            widget.node.child,
          ),
        );

      case 'AppBar':
        return Container(
          height:
              50,
          color:
              _color(
                p['backgroundColor'],
                fallback:
                    const Color(
                  0xFF1976D2,
                ),
              ),
          padding:
              const EdgeInsets.symmetric(
            horizontal:
                14,
          ),
          alignment:
              Alignment.centerLeft,
          child:
              Text(
            _string(
              p['title'],
              'Titre',
            ),
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontSize:
                  17,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        );

      default:
        try {
          return parser.build(
            widget.node,
          );
        } catch (_) {
          return Container(
            padding:
                const EdgeInsets.all(
              8,
            ),
            color:
                Colors.red.withOpacity(
              0.08,
            ),
            child:
                Text(
              widget.node.type,
              style:
                  const TextStyle(
                color:
                    Colors.redAccent,
                fontSize:
                    10,
              ),
            ),
          );
        }
    }
  }

  Widget _buildButton(
    Map<String, dynamic> p,
  ) {
    final text =
        _string(
      p['text'],
      'Bouton',
    );

    switch (
        _string(
          p['buttonType'],
          'elevated',
        )) {
      case 'text':
        return IgnorePointer(
          child:
              TextButton(
            onPressed:
                () {},
            child:
                Text(
              text,
            ),
          ),
        );

      case 'outlined':
        return IgnorePointer(
          child:
              OutlinedButton(
            onPressed:
                () {},
            child:
                Text(
              text,
            ),
          ),
        );

      default:
        return IgnorePointer(
          child:
              ElevatedButton(
            onPressed:
                () {},
            child:
                Text(
              text,
            ),
          ),
        );
    }
  }

  Widget _buildImage(
    Map<String, dynamic> p,
  ) {
    final src =
        _string(
      p['src'],
      '',
    );

    final width =
        _double(
              p['width'],
            ) ??
            100;

    final height =
        _double(
              p['height'],
            ) ??
            100;

    if (src.isEmpty) {
      return Container(
        width:
            width,
        height:
            height,
        color:
            const Color(
          0xFFE7E7EB,
        ),
        child:
            const Icon(
          Icons.image_outlined,
          color:
              Colors.black38,
          size:
              34,
        ),
      );
    }

    if (src.startsWith(
      'http://',
    ) ||
        src.startsWith(
          'https://',
        )) {
      return Image.network(
        src,
        width:
            width,
        height:
            height,
        fit:
            BoxFit.cover,
        errorBuilder:
            (_, __, ___) =>
                Container(
          width:
              width,
          height:
              height,
          color:
              Colors.grey.shade200,
          child:
              const Icon(
            Icons.broken_image_outlined,
            color:
                Colors.black38,
          ),
        ),
      );
    }

    return Image.asset(
      src,
      width:
          width,
      height:
          height,
      fit:
          BoxFit.cover,
      errorBuilder:
          (_, __, ___) =>
              Container(
        width:
            width,
        height:
            height,
        color:
            Colors.grey.shade200,
        child:
            const Icon(
          Icons.broken_image_outlined,
          color:
              Colors.black38,
        ),
      ),
    );
  }

  Widget _single(
    List<Widget> children,
    WidgetNode? fallbackNode,
  ) {
    if (children.isNotEmpty) {
      return children.first;
    }

    return const SizedBox.shrink();
  }

  double? _double(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ??
          '',
    );
  }

  int _integer(
    dynamic value,
    int fallback,
  ) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ??
              '',
        ) ??
        fallback;
  }

  int? _integerNullable(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  String _string(
    dynamic value,
    String fallback,
  ) {
    if (value == null) {
      return fallback;
    }

    return value.toString();
  }

  EdgeInsets _padding(
    dynamic value, {
    EdgeInsets fallback =
        EdgeInsets.zero,
  }) {
    if (value is num) {
      return EdgeInsets.all(
        value.toDouble(),
      );
    }

    if (value is Map) {
      if (value['all'] != null) {
        return EdgeInsets.all(
          _double(
                value['all'],
              ) ??
              0,
        );
      }

      return EdgeInsets.only(
        left:
            _double(
                  value['left'],
                ) ??
                0,
        top:
            _double(
                  value['top'],
                ) ??
                0,
        right:
            _double(
                  value['right'],
                ) ??
                0,
        bottom:
            _double(
                  value['bottom'],
                ) ??
                0,
      );
    }

    return fallback;
  }

  Color _color(
    dynamic value, {
    required Color fallback,
  }) {
    if (value is Color) {
      return value;
    }

    final raw =
        value?.toString()
            .replaceAll(
              '#',
              '',
            );

    if (raw == null ||
        raw.isEmpty) {
      return fallback;
    }

    try {
      if (raw.length == 6) {
        return Color(
          int.parse(
            'FF$raw',
            radix:
                16,
          ),
        );
      }

      if (raw.length == 8) {
        return Color(
          int.parse(
            raw,
            radix:
                16,
          ),
        );
      }
    } catch (_) {}

    return fallback;
  }

  BorderRadius _radius(
    dynamic value,
  ) {
    return BorderRadius.circular(
      _double(value) ??
          0,
    );
  }

  Alignment _alignment(
    dynamic value,
  ) {
    switch (
        value?.toString()) {
      case 'topLeft':
        return Alignment
            .topLeft;
      case 'topCenter':
        return Alignment
            .topCenter;
      case 'topRight':
        return Alignment
            .topRight;
      case 'centerLeft':
        return Alignment
            .centerLeft;
      case 'centerRight':
        return Alignment
            .centerRight;
      case 'bottomLeft':
        return Alignment
            .bottomLeft;
      case 'bottomCenter':
        return Alignment
            .bottomCenter;
      case 'bottomRight':
        return Alignment
            .bottomRight;
      default:
        return Alignment
            .center;
    }
  }

  MainAxisAlignment _mainAxis(
    dynamic value,
  ) {
    switch (
        value?.toString()) {
      case 'center':
        return MainAxisAlignment
            .center;
      case 'end':
        return MainAxisAlignment
            .end;
      case 'spaceBetween':
        return MainAxisAlignment
            .spaceBetween;
      case 'spaceAround':
        return MainAxisAlignment
            .spaceAround;
      case 'spaceEvenly':
        return MainAxisAlignment
            .spaceEvenly;
      default:
        return MainAxisAlignment
            .start;
    }
  }

  CrossAxisAlignment _crossAxis(
    dynamic value,
  ) {
    switch (
        value?.toString()) {
      case 'start':
        return CrossAxisAlignment
            .start;
      case 'end':
        return CrossAxisAlignment
            .end;
      case 'stretch':
        return CrossAxisAlignment
            .stretch;
      default:
        return CrossAxisAlignment
            .center;
    }
  }

  TextAlign _textAlign(
    dynamic value,
  ) {
    switch (
        value?.toString()) {
      case 'center':
        return TextAlign
            .center;
      case 'right':
        return TextAlign
            .right;
      case 'justify':
        return TextAlign
            .justify;
      default:
        return TextAlign
            .left;
    }
  }

  FontWeight _fontWeight(
    dynamic value,
  ) {
    switch (
        value?.toString()) {
      case 'bold':
        return FontWeight
            .bold;
      case 'w600':
        return FontWeight
            .w600;
      case 'w500':
        return FontWeight
            .w500;
      default:
        return FontWeight
            .normal;
    }
  }

  IconData _icon(
    String name,
  ) {
    switch (name) {
      case 'home':
        return Icons.home;
      case 'settings':
        return Icons.settings;
      case 'menu':
        return Icons.menu;
      case 'search':
        return Icons.search;
      case 'add':
        return Icons.add;
      case 'delete':
        return Icons.delete;
      case 'edit':
        return Icons.edit;
      case 'favorite':
      case 'heart':
        return Icons.favorite;
      case 'person':
        return Icons.person;
      case 'check':
        return Icons.check;
      case 'close':
        return Icons.close;
      case 'arrow_back':
        return Icons.arrow_back;
      case 'arrow_forward':
        return Icons.arrow_forward;
      case 'chevron_right':
        return Icons.chevron_right;
      case 'play_arrow':
        return Icons.play_arrow;
      case 'pause':
        return Icons.pause;
      case 'info':
        return Icons.info;
      case 'warning':
        return Icons.warning;
      default:
        return Icons.star;
    }
  }
}

/// ============================================================================
/// GRILLE
/// ============================================================================

class _GridBackground
    extends StatelessWidget {
  const _GridBackground();

  @override
  Widget build(
    BuildContext context,
  ) {
    return CustomPaint(
      painter:
          _GridPainter(),
      child:
          const ColoredBox(
        color:
            Color(
          0xFF08080C,
        ),
      ),
    );
  }
}

class _GridPainter
    extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    const spacing =
        24.0;

    final paint =
        Paint()
          ..color =
              Colors.white
                  .withOpacity(
            0.022,
          )
          ..strokeWidth =
              1;

    for (
      double x = 0;
      x <
          size.width;
      x += spacing
    ) {
      canvas.drawLine(
        Offset(
          x,
          0,
        ),
        Offset(
          x,
          size.height,
        ),
        paint,
      );
    }

    for (
      double y = 0;
      y <
          size.height;
      y += spacing
    ) {
      canvas.drawLine(
        Offset(
          0,
          y,
        ),
        Offset(
          size.width,
          y,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _GridPainter oldDelegate,
  ) =>
      false;
}