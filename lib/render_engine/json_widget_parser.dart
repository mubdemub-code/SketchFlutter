import 'package:flutter/material.dart';

import '../models/project_model.dart';
import '../models/widget_node.dart';
import 'render_context.dart';

import 'widget_builders/scaffold_builder.dart';
import 'widget_builders/container_builder.dart';
import 'widget_builders/text_builder.dart';
import 'widget_builders/row_column_builder.dart';
import 'widget_builders/button_builder.dart';
import 'widget_builders/image_builder.dart';
import 'widget_builders/icon_builder.dart';
import 'widget_builders/textfield_builder.dart';
import 'widget_builders/checkbox_builder.dart';
import 'widget_builders/switch_builder.dart';
import 'widget_builders/slider_builder.dart';
import 'widget_builders/listview_builder.dart';
import 'widget_builders/gridview_builder.dart';
import 'widget_builders/listtile_builder.dart';
import 'widget_builders/appbar_builder.dart';
import 'widget_builders/sizedbox_builder.dart';
import 'widget_builders/padding_builder.dart';
import 'widget_builders/center_builder.dart';

/// ============================================================================
/// TYPES D'ÉVÉNEMENTS D'ÉDITION
/// ============================================================================

typedef WidgetSelectCallback = void Function(
  WidgetNode node,
);

typedef WidgetDropCallback = void Function(
  WidgetNode target,
  String draggedType,
  int index,
);

typedef WidgetMoveCallback = void Function(
  String widgetId,
  String? newParentId,
  int newIndex,
);

typedef WidgetDeleteCallback = void Function(
  WidgetNode node,
);

typedef WidgetDuplicateCallback = void Function(
  WidgetNode node,
);

typedef WidgetHoverCallback = void Function(
  WidgetNode? node,
);

typedef WidgetContextMenuCallback = void Function(
  WidgetNode node,
);

/// ============================================================================
/// DONNÉES DE DRAG & DROP
/// ============================================================================
///
/// Cette classe est volontairement indépendante du DesignTab.
///
/// Tu peux donc faire venir le Drag d'une palette, d'un widget existant,
/// d'une bibliothèque de composants, etc.
///
class WidgetDragData {
  final String type;

  /// ID du widget existant lors d'un déplacement interne.
  ///
  /// null = nouveau widget venant de la palette.
  final String? existingWidgetId;

  /// Parent actuel lors d'un déplacement.
  final String? sourceParentId;

  const WidgetDragData({
    required this.type,
    this.existingWidgetId,
    this.sourceParentId,
  });

  bool get isExistingWidget =>
      existingWidgetId != null;
}

/// ============================================================================
/// ZONE DE DROP
/// ============================================================================

enum WidgetDropZone {
  before,
  inside,
  after,
}

/// ============================================================================
/// OPTIONS DU MODE ÉDITEUR
/// ============================================================================

class JsonWidgetEditorOptions {
  /// Active la couche d'édition.
  final bool enabled;

  /// ID du widget actuellement sélectionné.
  final String? selectedWidgetId;

  /// Afficher les bordures / overlays.
  final bool showSelection;

  /// Afficher les zones de drop.
  final bool showDropZones;

  /// Autoriser les nouveaux widgets.
  final bool allowInsert;

  /// Autoriser le déplacement des widgets existants.
  final bool allowMove;

  /// Autoriser la sélection.
  final bool allowSelection;

  /// Affiche le nom/type du widget sélectionné.
  final bool showLabels;

  /// Callback lors d'une sélection.
  final WidgetSelectCallback? onSelect;

  /// Callback de hover.
  final WidgetHoverCallback? onHover;

  /// Nouveau widget ou déplacement.
  ///
  /// target = widget sur lequel le drop arrive.
  /// draggedType = type du widget transporté.
  /// index = position souhaitée dans les enfants.
  final WidgetDropCallback? onDrop;

  /// Déplacement explicite d'un widget existant.
  final WidgetMoveCallback? onMove;

  /// Suppression.
  final WidgetDeleteCallback? onDelete;

  /// Duplication.
  final WidgetDuplicateCallback? onDuplicate;

  /// Menu contextuel.
  final WidgetContextMenuCallback? onContextMenu;

  /// Couleur de sélection.
  final Color selectionColor;

  /// Couleur des zones de drop.
  final Color dropColor;

  const JsonWidgetEditorOptions({
    this.enabled = false,
    this.selectedWidgetId,
    this.showSelection = true,
    this.showDropZones = true,
    this.allowInsert = true,
    this.allowMove = true,
    this.allowSelection = true,
    this.showLabels = true,
    this.onSelect,
    this.onHover,
    this.onDrop,
    this.onMove,
    this.onDelete,
    this.onDuplicate,
    this.onContextMenu,
    this.selectionColor = const Color(0xFF00E5FF),
    this.dropColor = const Color(0xFF00E5FF),
  });
}

/// ============================================================================
/// PARSER PRINCIPAL JSON → FLUTTER
/// ============================================================================
///
/// Ce parser fonctionne dans deux modes :
///
/// 1. MODE RUNTIME
///    editorOptions.enabled == false
///
///    => rendu normal, exactement comme ton parser actuel.
///
/// 2. MODE DESIGNER
///    editorOptions.enabled == true
///
///    => chaque WidgetNode devient sélectionnable,
///       draggable si nécessaire,
///       cible de drop,
///       entouré par les overlays d'édition.
///
/// Cette architecture permet de conserver un seul moteur de rendu pour :
///
/// - Preview
/// - Design Studio
/// - Runtime
/// - génération de projet
///
class JsonWidgetParser {
  final RenderContext context;

  /// Événements logiques.
  final void Function(
    String widgetId,
    String eventName,
  )? onEvent;

  /// Couche édition.
  final JsonWidgetEditorOptions editorOptions;

  JsonWidgetParser({
    required this.context,
    this.onEvent,
    this.editorOptions =
        const JsonWidgetEditorOptions(),
  });

  // ==========================================================================
  // API PUBLIQUE
  // ==========================================================================

  /// API historique.
  ///
  /// Cette méthode reste volontairement identique :
  ///
  ///     parser.build(rootWidget)
  ///
  /// continue de fonctionner sans aucune modification ailleurs.
  Widget build(
    WidgetNode node,
  ) {
    return _buildNode(
      node,
      parent: null,
      childIndex: 0,
    );
  }

  /// Construit explicitement le mode designer.
  Widget buildEditor(
    WidgetNode node,
  ) {
    return _buildNode(
      node,
      parent: null,
      childIndex: 0,
      forceEditor: true,
    );
  }

  // ==========================================================================
  // CONSTRUCTION RÉCURSIVE
  // ==========================================================================

  Widget _buildNode(
    WidgetNode node, {
    WidgetNode? parent,
    int childIndex = 0,
    bool forceEditor = false,
  }) {
    final bool editMode =
        forceEditor || editorOptions.enabled;

    Widget result;

    try {
      result = _buildCoreNode(
        node,
        parent: parent,
        childIndex: childIndex,
        forceEditor: forceEditor,
      );
    } catch (error, stackTrace) {
      result = _buildErrorWidget(
        node,
        error,
        stackTrace,
        editorMode: editMode,
      );
    }

    if (!editMode) {
      return result;
    }

    return _wrapEditableNode(
      node,
      result,
      parent: parent,
      childIndex: childIndex,
    );
  }

  // ==========================================================================
  // CORE BUILDER
  // ==========================================================================

  Widget _buildCoreNode(
    WidgetNode node, {
    WidgetNode? parent,
    int childIndex = 0,
    bool forceEditor = false,
  }) {
    final Widget? childWidget =
        node.child == null
            ? null
            : _buildNode(
                node.child!,
                parent: node,
                childIndex: 0,
                forceEditor: forceEditor,
              );

    final List<Widget> childrenWidgets =
        <Widget>[];

    final children =
        node.children;

    if (children != null &&
        children.isNotEmpty) {
      for (
        int i = 0;
        i < children.length;
        i++
      ) {
        childrenWidgets.add(
          _buildNode(
            children[i],
            parent: node,
            childIndex: i,
            forceEditor: forceEditor,
          ),
        );
      }
    }

    switch (node.type) {
      // ======================================================================
      // SCAFFOLD
      // ======================================================================

      case 'Scaffold':
        return _buildScaffold(
          node,
        );

      // ======================================================================
      // CONTAINER
      // ======================================================================

      case 'Container':
        return ContainerBuilder.build(
          node,
          childWidget,
          context,
        );

      // ======================================================================
      // TEXT
      // ======================================================================

      case 'Text':
        return TextBuilder.build(
          node,
          context,
        );

      // ======================================================================
      // ROW / COLUMN
      // ======================================================================

      case 'Row':
      case 'Column':
        return RowColumnBuilder.build(
          node,
          childrenWidgets,
          context,
        );

      // ======================================================================
      // STACK
      // ======================================================================

      case 'Stack':
        return _buildStack(
          node,
          childrenWidgets,
        );

      // ======================================================================
      // ALIGN
      // ======================================================================

      case 'Align':
        return _buildAlign(
          node,
          childWidget,
        );

      // ======================================================================
      // CENTER
      // ======================================================================

      case 'Center':
        return CenterBuilder.build(
          node,
          childWidget,
          context,
        );

      // ======================================================================
      // PADDING
      // ======================================================================

      case 'Padding':
        return PaddingBuilder.build(
          node,
          childWidget,
          context,
        );

      // ======================================================================
      // SIZED BOX
      // ======================================================================

      case 'SizedBox':
        return SizedBoxBuilder.build(
          node,
          childWidget,
          context,
        );

      // ======================================================================
      // BUTTON
      // ======================================================================

      case 'Button':
      case 'ElevatedButton':
      case 'TextButton':
      case 'OutlinedButton':
        return ButtonBuilder.build(
          node,
          childWidget,
          () {
            _triggerEvent(
              node,
              'onPressed',
            );
          },
          context,
        );

      // ======================================================================
      // IMAGE
      // ======================================================================

      case 'Image':
        return ImageBuilder.build(
          node,
          context,
        );

      // ======================================================================
      // ICON
      // ======================================================================

      case 'Icon':
        return IconBuilder.build(
          node,
          context,
        );

      // ======================================================================
      // TEXTFIELD
      // ======================================================================

      case 'TextField':
        return TextFieldBuilder.build(
          node,
          context,
          onChanged: (value) {
            _triggerEvent(
              node,
              'onChanged',
            );
          },
        );

      // ======================================================================
      // CHECKBOX
      // ======================================================================

      case 'Checkbox':
        return CheckboxBuilder.build(
          node,
          context,
          onChanged: (value) {
            _triggerEvent(
              node,
              'onChanged',
            );
          },
        );

      // ======================================================================
      // SWITCH
      // ======================================================================

      case 'Switch':
        return SwitchBuilder.build(
          node,
          context,
          onChanged: (value) {
            _triggerEvent(
              node,
              'onChanged',
            );
          },
        );

      // ======================================================================
      // SLIDER
      // ======================================================================

      case 'Slider':
        return SliderBuilder.build(
          node,
          context,
          onChanged: (value) {
            _triggerEvent(
              node,
              'onChanged',
            );
          },
        );

      // ======================================================================
      // LIST VIEW
      // ======================================================================

      case 'ListView':
        return ListViewBuilder.build(
          node,
          childrenWidgets,
          context,
        );

      // ======================================================================
      // GRID VIEW
      // ======================================================================

      case 'GridView':
        return GridViewBuilder.build(
          node,
          childrenWidgets,
          context,
        );

      // ======================================================================
      // LIST TILE
      // ======================================================================

      case 'ListTile':
        return ListTileBuilder.build(
          node,
          context,
          onTap: () {
            _triggerEvent(
              node,
              'onTap',
            );
          },
        );

      // ======================================================================
      // APP BAR
      // ======================================================================

      case 'AppBar':
        return AppBarBuilder.build(
          node,
          context,
        );

      // ======================================================================
      // WRAP
      // ======================================================================

      case 'Wrap':
        return _buildWrap(
          node,
          childrenWidgets,
        );

      // ======================================================================
      // CARD
      // ======================================================================

      case 'Card':
        return _buildCard(
          node,
          childWidget,
        );

      // ======================================================================
      // EXPANDED
      // ======================================================================

      case 'Expanded':
        return Expanded(
          flex: _readInt(
            node,
            'flex',
            fallback: 1,
          ),
          child: childWidget ??
              const SizedBox.shrink(),
        );

      // ======================================================================
      // FLEXIBLE
      // ======================================================================

      case 'Flexible':
        return Flexible(
          flex: _readInt(
            node,
            'flex',
            fallback: 1,
          ),
          fit: _readFlexFit(
            node,
          ),
          child: childWidget ??
              const SizedBox.shrink(),
        );

      // ======================================================================
      // SPACER
      // ======================================================================

      case 'Spacer':
        return Spacer(
          flex: _readInt(
            node,
            'flex',
            fallback: 1,
          ),
        );

      // ======================================================================
      // SAFE AREA
      // ======================================================================

      case 'SafeArea':
        return SafeArea(
          top: _readBool(
            node,
            'top',
            fallback: true,
          ),
          bottom: _readBool(
            node,
            'bottom',
            fallback: true,
          ),
          left: _readBool(
            node,
            'left',
            fallback: true,
          ),
          right: _readBool(
            node,
            'right',
            fallback: true,
          ),
          child: childWidget ??
              const SizedBox.shrink(),
        );

      // ======================================================================
      // SCROLL
      // ======================================================================

      case 'SingleChildScrollView':
        return SingleChildScrollView(
          scrollDirection:
              _readAxis(
            node,
            'scrollDirection',
          ),
          child: childWidget ??
              const SizedBox.shrink(),
        );

      // ======================================================================
      // VISIBILITY
      // ======================================================================

      case 'Visibility':
        return Visibility(
          visible: _readBool(
            node,
            'visible',
            fallback: true,
          ),
          maintainState: _readBool(
            node,
            'maintainState',
            fallback: false,
          ),
          maintainAnimation:
              _readBool(
            node,
            'maintainAnimation',
            fallback: false,
          ),
          maintainSize: _readBool(
            node,
            'maintainSize',
            fallback: false,
          ),
          child: childWidget ??
              const SizedBox.shrink(),
        );

      // ======================================================================
      // OPACITY
      // ======================================================================

      case 'Opacity':
        return Opacity(
          opacity: _readDouble(
            node,
            'opacity',
            fallback: 1.0,
          ).clamp(0.0, 1.0),
          alwaysIncludeSemantics:
              _readBool(
            node,
            'alwaysIncludeSemantics',
            fallback: false,
          ),
          child: childWidget ??
              const SizedBox.shrink(),
        );

      // ======================================================================
      // DIVIDER
      // ======================================================================

      case 'Divider':
        return Divider(
          height: _readDouble(
            node,
            'height',
            fallback: 16,
          ),
          thickness: _readDouble(
            node,
            'thickness',
            fallback: 1,
          ),
          indent: _readDouble(
            node,
            'indent',
            fallback: 0,
          ),
          endIndent: _readDouble(
            node,
            'endIndent',
            fallback: 0,
          ),
        );

      // ======================================================================
      // FALLBACK
      // ======================================================================

      default:
        return _buildUnknownWidget(
          node,
          childWidget,
          childrenWidgets,
        );
    }
  }

  // ==========================================================================
  // SCAFFOLD
  // ==========================================================================

  Widget _buildScaffold(
    WidgetNode node,
  ) {
    Widget? appBar;
    Widget? body;

    final appBarNode =
        _findChildByType(
      node,
      'AppBar',
    );

    final bodyNode =
        _findFirstBodyNode(
      node,
    );

    if (appBarNode != null) {
      try {
        appBar =
            _buildNode(
          appBarNode,
          parent: node,
        );
      } catch (_) {
        appBar = null;
      }
    }

    if (bodyNode != null) {
      try {
        body =
            _buildNode(
          bodyNode,
          parent: node,
        );
      } catch (_) {
        body = null;
      }
    }

    return ScaffoldBuilder.build(
      node,
      appBar,
      body,
      context,
    );
  }

  // ==========================================================================
  // STACK
  // ==========================================================================

  Widget _buildStack(
    WidgetNode node,
    List<Widget> children,
  ) {
    return Stack(
      alignment:
          _readAlignment(
        node,
        'alignment',
      ),
      fit:
          _readStackFit(node),
      clipBehavior:
          _readClip(node),
      children: children,
    );
  }

  // ==========================================================================
  // ALIGN
  // ==========================================================================

  Widget _buildAlign(
    WidgetNode node,
    Widget? child,
  ) {
    return Align(
      alignment:
          _readAlignment(
        node,
        'alignment',
      ),
      widthFactor:
          _readNullableDouble(
        node,
        'widthFactor',
      ),
      heightFactor:
          _readNullableDouble(
        node,
        'heightFactor',
      ),
      child: child ??
          const SizedBox.shrink(),
    );
  }

  // ==========================================================================
  // WRAP
  // ==========================================================================

  Widget _buildWrap(
    WidgetNode node,
    List<Widget> children,
  ) {
    return Wrap(
      direction:
          _readAxis(
        node,
        'direction',
      ),
      alignment:
          _readWrapAlignment(
        node,
        'alignment',
      ),
      runAlignment:
          _readWrapAlignment(
        node,
        'runAlignment',
      ),
      crossAxisAlignment:
          _readWrapCrossAlignment(
        node,
        'crossAxisAlignment',
      ),
      spacing: _readDouble(
        node,
        'spacing',
        fallback: 0,
      ),
      runSpacing:
          _readDouble(
        node,
        'runSpacing',
        fallback: 0,
      ),
      children: children,
    );
  }

  // ==========================================================================
  // CARD
  // ==========================================================================

  Widget _buildCard(
    WidgetNode node,
    Widget? child,
  ) {
    return Card(
      elevation:
          _readDouble(
        node,
        'elevation',
        fallback: 1,
      ),
      margin:
          _readEdgeInsets(
        node,
        'margin',
        fallback:
            const EdgeInsets.all(4),
      ),
      color:
          _readColor(
        node,
        'color',
        fallback: null,
      ),
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          _readDouble(
            node,
            'borderRadius',
            fallback: 10,
          ),
        ),
      ),
      child: child ??
          const SizedBox.shrink(),
    );
  }

  // ==========================================================================
  // COUCHE ÉDITEUR
  // ==========================================================================

  Widget _wrapEditableNode(
    WidgetNode node,
    Widget child, {
    WidgetNode? parent,
    int childIndex = 0,
  }) {
    final bool selected =
        editorOptions.selectedWidgetId ==
            node.id;

    Widget editable =
        child;

    // ------------------------------------------------------------------------
    // DRAG TARGET
    // ------------------------------------------------------------------------

    if (editorOptions.allowInsert &&
        _acceptsChildren(node)) {
      editable =
          DragTarget<WidgetDragData>(
        onWillAcceptWithDetails: (
          details,
        ) {
          if (!editorOptions.enabled) {
            return false;
          }

          if (!_acceptsDrag(
            node,
            details.data,
          )) {
            return false;
          }

          editorOptions.onHover
              ?.call(node);

          return true;
        },
        onLeave: (_) {
          editorOptions.onHover
              ?.call(null);
        },
        onAcceptWithDetails: (
          details,
        ) {
          editorOptions.onHover
              ?.call(null);

          final data =
              details.data;

          final int insertIndex =
              _resolveDropIndex(
            node,
          );

          if (data.isExistingWidget &&
              editorOptions.allowMove) {
            editorOptions.onMove
                ?.call(
              data.existingWidgetId!,
              node.id,
              insertIndex,
            );
          } else {
            editorOptions.onDrop
                ?.call(
              node,
              data.type,
              insertIndex,
            );
          }
        },
        builder: (
          context,
          candidateData,
          rejectedData,
        ) {
          final bool hovering =
              candidateData.isNotEmpty;

          return AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 100,
            ),
            decoration:
                hovering &&
                        editorOptions
                            .showDropZones
                    ? BoxDecoration(
                        border: Border.all(
                          color:
                              editorOptions
                                  .dropColor,
                          width: 2,
                        ),
                        color:
                            editorOptions
                                .dropColor
                                .withOpacity(
                          0.05,
                        ),
                      )
                    : null,
            child: editable,
          );
        },
      );
    }

    // ------------------------------------------------------------------------
    // SÉLECTION
    // ------------------------------------------------------------------------

    if (editorOptions.allowSelection) {
      editable =
          GestureDetector(
        behavior:
            HitTestBehavior.opaque,
        onTap: () {
          editorOptions.onSelect
              ?.call(node);
        },
        onSecondaryTap: () {
          editorOptions
              .onContextMenu
              ?.call(node);
        },
        onLongPress: () {
          editorOptions
              .onContextMenu
              ?.call(node);
        },
        child: editable,
      );
    }

    // ------------------------------------------------------------------------
    // DRAG D'UN WIDGET EXISTANT
    // ------------------------------------------------------------------------

    if (editorOptions.allowMove) {
      editable =
          LongPressDraggable<
              WidgetDragData>(
        data:
            WidgetDragData(
          type: node.type,
          existingWidgetId:
              node.id,
          sourceParentId:
              parent?.id,
        ),
        maxSimultaneousDrags:
            1,
        feedback:
            _buildDragFeedback(
          node,
        ),
        childWhenDragging:
            Opacity(
          opacity: 0.20,
          child: editable,
        ),
        child: editable,
      );
    }

    // ------------------------------------------------------------------------
    // OVERLAY DE SÉLECTION
    // ------------------------------------------------------------------------

    if (editorOptions.showSelection &&
        selected) {
      editable =
          _buildSelectionOverlay(
        node,
        editable,
      );
    }

    return editable;
  }

  // ==========================================================================
  // SÉLECTION OVERLAY
  // ==========================================================================

  Widget _buildSelectionOverlay(
    WidgetNode node,
    Widget child,
  ) {
    return Stack(
      clipBehavior:
          Clip.none,
      children: [
        child,

        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration:
                  BoxDecoration(
                border: Border.all(
                  color:
                      editorOptions
                          .selectionColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),

        if (editorOptions.showLabels)
          Positioned(
            left: 0,
            top: 0,
            child: IgnorePointer(
              child: Container(
                constraints:
                    const BoxConstraints(
                  maxWidth: 140,
                ),
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      editorOptions
                          .selectionColor,
                  borderRadius:
                      const BorderRadius
                          .only(
                    bottomRight:
                        Radius.circular(
                      5,
                    ),
                  ),
                ),
                child: Text(
                  node.type,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color: Colors.black,
                    fontSize: 8,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),

        Positioned(
          right: 0,
          bottom: 0,
          child:
              _buildSelectionToolbar(
            node,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // MINI TOOLBAR
  // ==========================================================================

  Widget _buildSelectionToolbar(
    WidgetNode node,
  ) {
    return Material(
      color: const Color(
        0xFF17171E,
      ),
      borderRadius:
          BorderRadius.circular(
        7,
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          _toolbarIcon(
            Icons.copy,
            () {
              editorOptions
                  .onDuplicate
                  ?.call(node);
            },
          ),
          _toolbarIcon(
            Icons.delete_outline,
            () {
              editorOptions
                  .onDelete
                  ?.call(node);
            },
          ),
        ],
      ),
    );
  }

  Widget _toolbarIcon(
    IconData icon,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius:
          BorderRadius.circular(
        7,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          5,
        ),
        child: Icon(
          icon,
          size: 14,
          color: Colors.white70,
        ),
      ),
    );
  }

  // ==========================================================================
  // DRAG FEEDBACK
  // ==========================================================================

  Widget _buildDragFeedback(
    WidgetNode node,
  ) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints:
            const BoxConstraints(
          minWidth: 70,
          maxWidth: 180,
          minHeight: 44,
          maxHeight: 100,
        ),
        padding:
            const EdgeInsets.all(
          10,
        ),
        decoration:
            BoxDecoration(
          color:
              const Color(0xFF23232D),
          borderRadius:
              BorderRadius.circular(
            10,
          ),
          border:
              Border.all(
            color:
                editorOptions
                    .selectionColor,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color:
                  Colors.black54,
              blurRadius:
                  15,
              spreadRadius:
                  2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.drag_indicator,
              color:
                  editorOptions
                      .selectionColor,
              size: 18,
            ),
            const SizedBox(
              width: 6,
            ),
            Flexible(
              child: Text(
                node.type,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // DROP INDEX
  // ==========================================================================

  int _resolveDropIndex(
    WidgetNode target,
  ) {
    final children =
        target.children;

    if (children == null ||
        children.isEmpty) {
      return 0;
    }

    return children.length;
  }

  // ==========================================================================
  // TYPES CONTENEURS
  // ==========================================================================

  bool _acceptsChildren(
    WidgetNode node,
  ) {
    switch (node.type) {
      case 'Container':
      case 'Column':
      case 'Row':
      case 'Stack':
      case 'Center':
      case 'Align':
      case 'Padding':
      case 'SizedBox':
      case 'ListView':
      case 'GridView':
      case 'Wrap':
      case 'Card':
      case 'Scaffold':
      case 'Expanded':
      case 'Flexible':
      case 'SafeArea':
      case 'SingleChildScrollView':
      case 'Visibility':
      case 'Opacity':
        return true;

      default:
        return false;
    }
  }

  bool _acceptsDrag(
    WidgetNode target,
    WidgetDragData data,
  ) {
    if (!_acceptsChildren(target)) {
      return false;
    }

    // Empêche un widget d'être déposé dans lui-même.
    if (data.existingWidgetId ==
        target.id) {
      return false;
    }

    return true;
  }

  // ==========================================================================
  // ÉVÉNEMENTS
  // ==========================================================================

  void _triggerEvent(
    WidgetNode node,
    String eventName,
  ) {
    if (onEvent == null) {
      return;
    }

    try {
      onEvent!(
        node.id,
        eventName,
      );
    } catch (_) {
      // Ne jamais casser le rendu à cause
      // d'une erreur du moteur logique.
    }
  }

  // ==========================================================================
  // RECHERCHE D'ENFANTS
  // ==========================================================================

  WidgetNode? _findChildByType(
    WidgetNode node,
    String type,
  ) {
    final child =
        node.child;

    if (child != null &&
        child.type == type) {
      return child;
    }

    final children =
        node.children;

    if (children != null) {
      for (final item
          in children) {
        if (item.type == type) {
          return item;
        }
      }
    }

    return null;
  }

  WidgetNode? _findFirstBodyNode(
    WidgetNode node,
  ) {
    final child =
        node.child;

    if (child != null &&
        child.type != 'AppBar') {
      return child;
    }

    final children =
        node.children;

    if (children != null) {
      for (final item
          in children) {
        if (item.type != 'AppBar') {
          return item;
        }
      }
    }

    return null;
  }

  // ==========================================================================
  // UNKNOWN WIDGET
  // ==========================================================================

  Widget _buildUnknownWidget(
    WidgetNode node,
    Widget? child,
    List<Widget> children,
  ) {
    // En mode runtime :
    // présentation discrète.
    if (!editorOptions.enabled) {
      return Container(
        padding:
            const EdgeInsets.all(8),
        decoration:
            BoxDecoration(
          color:
              Colors.grey.shade200,
          borderRadius:
              BorderRadius.circular(
            4,
          ),
        ),
        child: child ??
            (children.isNotEmpty
                ? Column(
                    children: children,
                  )
                : Text(
                    'Widget inconnu: ${node.type}',
                  )),
      );
    }

    // En mode designer :
    // placeholder clairement identifiable.
    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 36,
        minWidth: 60,
      ),
      padding:
          const EdgeInsets.all(8),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFFF9800,
        ).withOpacity(
          0.08,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFFF9800,
          ).withOpacity(
            0.55,
          ),
        ),
        borderRadius:
            BorderRadius.circular(
          6,
        ),
      ),
      child: child ??
          Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.extension_outlined,
                color:
                    Colors.orangeAccent,
                size: 22,
              ),
              const SizedBox(
                height: 4,
              ),
              Text(
                node.type,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      Colors.orangeAccent,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
    );
  }

  // ==========================================================================
  // ERREUR DE RENDU
  // ==========================================================================

  Widget _buildErrorWidget(
    WidgetNode node,
    Object error,
    StackTrace stackTrace, {
    required bool editorMode,
  }) {
    return Container(
      constraints:
          const BoxConstraints(
        minWidth: 50,
        minHeight: 35,
      ),
      padding:
          const EdgeInsets.all(7),
      decoration:
          BoxDecoration(
        color:
            Colors.red.withOpacity(
          editorMode ? 0.07 : 0.04,
        ),
        border:
            Border.all(
          color:
              Colors.redAccent
                  .withOpacity(
            editorMode ? 0.65 : 0.35,
          ),
        ),
        borderRadius:
            BorderRadius.circular(
          5,
        ),
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Erreur: ${node.type}',
            style:
                const TextStyle(
              color:
                  Colors.redAccent,
              fontWeight:
                  FontWeight.bold,
              fontSize: 10,
            ),
          ),
          if (editorMode)
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 3,
              ),
              child: Text(
                error.toString(),
                maxLines: 3,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color:
                      Colors.redAccent,
                  fontSize: 8,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PROPRIÉTÉS
  // ==========================================================================

  dynamic _property(
    WidgetNode node,
    String key,
  ) {
    try {
      final properties =
          node.properties;

      if (properties is Map) {
        return properties?[key];
      }
    } catch (_) {}

    return null;
  }

  double _readDouble(
    WidgetNode node,
    String key, {
    double fallback = 0,
  }) {
    final value =
        _property(
      node,
      key,
    );

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ??
              '',
        ) ??
        fallback;
  }

  double? _readNullableDouble(
    WidgetNode node,
    String key,
  ) {
    final value =
        _property(
      node,
      key,
    );

    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  int _readInt(
    WidgetNode node,
    String key, {
    int fallback = 0,
  }) {
    final value =
        _property(
      node,
      key,
    );

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ??
              '',
        ) ??
        fallback;
  }

  bool _readBool(
    WidgetNode node,
    String key, {
    bool fallback = false,
  }) {
    final value =
        _property(
      node,
      key,
    );

    if (value is bool) {
      return value;
    }

    if (value is String) {
      return value.toLowerCase() ==
          'true';
    }

    return fallback;
  }

  String _readString(
    WidgetNode node,
    String key, {
    String fallback = '',
  }) {
    final value =
        _property(
      node,
      key,
    );

    if (value == null) {
      return fallback;
    }

    return value.toString();
  }

  // ==========================================================================
  // COULEUR
  // ==========================================================================

  Color? _readColor(
    WidgetNode node,
    String key, {
    Color? fallback,
  }) {
    final value =
        _property(
      node,
      key,
    );

    if (value == null) {
      return fallback;
    }

    if (value is Color) {
      return value;
    }

    final raw =
        value.toString()
            .replaceAll(
              '#',
              '',
            )
            .trim();

    if (raw.isEmpty) {
      return fallback;
    }

    try {
      if (raw.length == 6) {
        return Color(
          int.parse(
            'FF$raw',
            radix: 16,
          ),
        );
      }

      if (raw.length == 8) {
        return Color(
          int.parse(
            raw,
            radix: 16,
          ),
        );
      }
    } catch (_) {}

    return fallback;
  }

  // ==========================================================================
  // PADDING / MARGIN
  // ==========================================================================

  EdgeInsets _readEdgeInsets(
    WidgetNode node,
    String key, {
    EdgeInsets fallback =
        EdgeInsets.zero,
  }) {
    final value =
        _property(
      node,
      key,
    );

    if (value == null) {
      return fallback;
    }

    if (value is num) {
      return EdgeInsets.all(
        value.toDouble(),
      );
    }

    if (value is Map) {
      return EdgeInsets.only(
        left:
            _mapDouble(
          value,
          'left',
        ),
        top:
            _mapDouble(
          value,
          'top',
        ),
        right:
            _mapDouble(
          value,
          'right',
        ),
        bottom:
            _mapDouble(
          value,
          'bottom',
        ),
      );
    }

    final number =
        double.tryParse(
      value.toString(),
    );

    if (number != null) {
      return EdgeInsets.all(
        number,
      );
    }

    return fallback;
  }

  double _mapDouble(
    Map map,
    String key,
  ) {
    final value =
        map[key];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ??
              '',
        ) ??
        0;
  }

  // ==========================================================================
  // ENUMS FLUTTER
  // ==========================================================================

  Alignment _readAlignment(
    WidgetNode node,
    String key,
  ) {
    final value =
        _readString(
      node,
      key,
      fallback: 'center',
    );

    switch (value) {
      case 'topLeft':
        return Alignment.topLeft;

      case 'topCenter':
        return Alignment.topCenter;

      case 'topRight':
        return Alignment.topRight;

      case 'centerLeft':
        return Alignment.centerLeft;

      case 'center':
        return Alignment.center;

      case 'centerRight':
        return Alignment.centerRight;

      case 'bottomLeft':
        return Alignment.bottomLeft;

      case 'bottomCenter':
        return Alignment.bottomCenter;

      case 'bottomRight':
        return Alignment.bottomRight;

      default:
        return Alignment.center;
    }
  }

  Axis _readAxis(
    WidgetNode node,
    String key,
  ) {
    final value =
        _readString(
      node,
      key,
      fallback: 'vertical',
    );

    return value ==
            'horizontal'
        ? Axis.horizontal
        : Axis.vertical;
  }

  StackFit _readStackFit(
    WidgetNode node,
  ) {
    final value =
        _readString(
      node,
      'fit',
      fallback: 'loose',
    );

    switch (value) {
      case 'expand':
        return StackFit.expand;

      case 'passthrough':
        return StackFit.passthrough;

      default:
        return StackFit.loose;
    }
  }

  Clip _readClip(
    WidgetNode node,
  ) {
    final value =
        _readString(
      node,
      'clipBehavior',
      fallback: 'hardEdge',
    );

    switch (value) {
      case 'none':
        return Clip.none;

      case 'antiAlias':
        return Clip.antiAlias;

      case 'antiAliasWithSaveLayer':
        return Clip.antiAliasWithSaveLayer;

      default:
        return Clip.hardEdge;
    }
  }

  WrapAlignment _readWrapAlignment(
    WidgetNode node,
    String key,
  ) {
    final value =
        _readString(
      node,
      key,
      fallback: 'start',
    );

    switch (value) {
      case 'center':
        return WrapAlignment.center;

      case 'end':
        return WrapAlignment.end;

      case 'spaceBetween':
        return WrapAlignment.spaceBetween;

      case 'spaceAround':
        return WrapAlignment.spaceAround;

      case 'spaceEvenly':
        return WrapAlignment.spaceEvenly;

      default:
        return WrapAlignment.start;
    }
  }

  WrapCrossAlignment
      _readWrapCrossAlignment(
    WidgetNode node,
    String key,
  ) {
    final value =
        _readString(
      node,
      key,
      fallback: 'start',
    );

    switch (value) {
      case 'center':
        return WrapCrossAlignment.center;

      case 'end':
        return WrapCrossAlignment.end;

      default:
        return WrapCrossAlignment.start;
    }
  }

  FlexFit _readFlexFit(
    WidgetNode node,
  ) {
    final value =
        _readString(
      node,
      'fit',
      fallback: 'loose',
    );

    return value == 'tight'
        ? FlexFit.tight
        : FlexFit.loose;
  }
}