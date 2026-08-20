import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/page_model.dart';
import '../models/project_model.dart';
import '../models/widget_node.dart';
import '../providers/editor_provider.dart';
import '../render_engine/json_widget_parser.dart';
import '../render_engine/render_context.dart';
import '../widgets/property_inspector.dart';

/// ===============================================================
/// DESIGN STUDIO - NEXT GENERATION
/// ===============================================================
///
/// Objectifs :
/// - Palette compacte
/// - Drag & Drop
/// - Drop sur téléphone
/// - Drop dans les widgets conteneurs
/// - Sélection de widgets existants
/// - Inspecteur dynamique
/// - Bottom-sheet rétractable
/// - Téléphone responsive
/// - Renderer éditable récursif
/// - Placeholders pour widgets invisibles
///
/// ===============================================================

class DesignTab extends ConsumerStatefulWidget {
  final ProjectModel project;

  const DesignTab({
    super.key,
    required this.project,
  });

  @override
  ConsumerState<DesignTab> createState() => _DesignTabState();
}

/// ----------------------------------------------------------------
/// Donnée transportée pendant le Drag & Drop.
/// ----------------------------------------------------------------
class _DesignDragData {
  final String type;

  const _DesignDragData({
    required this.type,
  });
}

/// ----------------------------------------------------------------
/// Élément de palette.
/// ----------------------------------------------------------------
class _PaletteItem {
  final String type;
  final IconData icon;
  final Color color;

  const _PaletteItem({
    required this.type,
    required this.icon,
    required this.color,
  });
}

class _DesignTabState extends ConsumerState<DesignTab>
    with TickerProviderStateMixin {
  // ==============================================================
  // CONFIGURATION
  // ==============================================================

  static const double _phoneBaseWidth = 350;
  static const double _phoneBaseHeight = 700;

  static const Color _background = Color(0xFF09090D);
  static const Color _panel = Color(0xFF111117);
  static const Color _panel2 = Color(0xFF171720);
  static const Color _tile = Color(0xFF1B1B26);
  static const Color _cyan = Color(0xFF00E5FF);

  // ==============================================================
  // KEYS / CONTROLLERS
  // ==============================================================

  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  final TextEditingController _searchController =
      TextEditingController();

  final ScrollController _paletteScrollController =
      ScrollController();

  // ==============================================================
  // ÉTAT LOCAL DE L'ÉDITEUR
  // ==============================================================

  String? _selectedNodeId;

  bool _inspectorVisible = false;

  double _inspectorDragOffset = 0;

  bool _showGrid = true;

  bool _showDropHints = true;

  String _searchQuery = '';

  final Set<String> _expandedCategories = <String>{};

  late final AnimationController _inspectorAnimationController;

  late final Animation<double> _inspectorAnimation;

  // ==============================================================
  // CATALOGUE DE WIDGETS
  // ==============================================================

  final Map<String, List<_PaletteItem>> _widgetCategories = {
    'Structure': const [
      _PaletteItem(
        type: 'Container',
        icon: Icons.crop_din,
        color: Colors.blueAccent,
      ),
      _PaletteItem(
        type: 'Column',
        icon: Icons.view_column,
        color: Colors.indigoAccent,
      ),
      _PaletteItem(
        type: 'Row',
        icon: Icons.table_rows,
        color: Colors.indigoAccent,
      ),
      _PaletteItem(
        type: 'Stack',
        icon: Icons.layers,
        color: Colors.deepPurpleAccent,
      ),
      _PaletteItem(
        type: 'Center',
        icon: Icons.center_focus_strong,
        color: Colors.cyanAccent,
      ),
      _PaletteItem(
        type: 'Align',
        icon: Icons.open_with,
        color: Colors.tealAccent,
      ),
      _PaletteItem(
        type: 'Padding',
        icon: Icons.space_bar,
        color: Colors.orangeAccent,
      ),
      _PaletteItem(
        type: 'SizedBox',
        icon: Icons.check_box_outline_blank,
        color: Colors.grey,
      ),
    ],
    'Base': const [
      _PaletteItem(
        type: 'Text',
        icon: Icons.text_fields,
        color: Colors.orangeAccent,
      ),
      _PaletteItem(
        type: 'Button',
        icon: Icons.smart_button,
        color: Colors.greenAccent,
      ),
      _PaletteItem(
        type: 'Icon',
        icon: Icons.star,
        color: Colors.yellowAccent,
      ),
      _PaletteItem(
        type: 'Image',
        icon: Icons.image,
        color: Colors.purpleAccent,
      ),
      _PaletteItem(
        type: 'Card',
        icon: Icons.credit_card,
        color: Colors.lightBlueAccent,
      ),
      _PaletteItem(
        type: 'Divider',
        icon: Icons.remove,
        color: Colors.white70,
      ),
    ],
    'Formulaires': const [
      _PaletteItem(
        type: 'TextField',
        icon: Icons.input,
        color: Colors.pinkAccent,
      ),
      _PaletteItem(
        type: 'Checkbox',
        icon: Icons.check_box,
        color: Colors.lightGreenAccent,
      ),
      _PaletteItem(
        type: 'Switch',
        icon: Icons.toggle_on,
        color: Colors.deepOrangeAccent,
      ),
      _PaletteItem(
        type: 'Slider',
        icon: Icons.linear_scale,
        color: Colors.amberAccent,
      ),
    ],
    'Listes': const [
      _PaletteItem(
        type: 'ListView',
        icon: Icons.format_list_bulleted,
        color: Colors.blueGrey,
      ),
      _PaletteItem(
        type: 'GridView',
        icon: Icons.grid_view,
        color: Colors.deepPurpleAccent,
      ),
      _PaletteItem(
        type: 'ListTile',
        icon: Icons.list_alt,
        color: Colors.lightBlueAccent,
      ),
      _PaletteItem(
        type: 'Wrap',
        icon: Icons.view_comfy_alt,
        color: Colors.tealAccent,
      ),
    ],
    'Mise en page': const [
      _PaletteItem(
        type: 'Expanded',
        icon: Icons.expand,
        color: Colors.cyan,
      ),
      _PaletteItem(
        type: 'Flexible',
        icon: Icons.unfold_more,
        color: Colors.lightBlue,
      ),
      _PaletteItem(
        type: 'Spacer',
        icon: Icons.space_bar,
        color: Colors.blueGrey,
      ),
      _PaletteItem(
        type: 'SafeArea',
        icon: Icons.security,
        color: Colors.greenAccent,
      ),
      _PaletteItem(
        type: 'SingleChildScrollView',
        icon: Icons.swap_vert,
        color: Colors.purpleAccent,
      ),
    ],
    'Composants': const [
      _PaletteItem(
        type: 'Scaffold',
        icon: Icons.web,
        color: Colors.tealAccent,
      ),
      _PaletteItem(
        type: 'AppBar',
        icon: Icons.web_asset,
        color: Colors.lightBlueAccent,
      ),
      _PaletteItem(
        type: 'Visibility',
        icon: Icons.visibility,
        color: Colors.orangeAccent,
      ),
      _PaletteItem(
        type: 'Opacity',
        icon: Icons.opacity,
        color: Colors.amberAccent,
      ),
    ],
  };

  // ==============================================================
  // INIT
  // ==============================================================

  @override
  void initState() {
    super.initState();

    _inspectorAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _inspectorAnimation = CurvedAnimation(
      parent: _inspectorAnimationController,
      curve: Curves.easeOutCubic,
    );

    for (final category in _widgetCategories.keys) {
      _expandedCategories.add(category);
    }

    _searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _paletteScrollController.dispose();
    _inspectorAnimationController.dispose();
    super.dispose();
  }

  // ==============================================================
  // UTILITAIRES
  // ==============================================================

  PageModel? _getCurrentPage() {
    final editorState = ref.read(editorProvider);

    final String? pageId = editorState.currentPageId;

    for (final page in widget.project.pages) {
      if (page.id == pageId) {
        return page;
      }
    }

    if (widget.project.pages.isNotEmpty) {
      return widget.project.pages.first;
    }

    return null;
  }

  WidgetNode? _findSelectedNode(
    WidgetNode? root,
  ) {
    if (root == null || _selectedNodeId == null) {
      return null;
    }

    return root.findById(_selectedNodeId!);
  }

  bool _canHaveChildren(WidgetNode node) {
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

    return types.contains(node.type);
  }

  bool _canHaveMultipleChildren(String type) {
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

  double _toDouble(
    dynamic value, {
    double fallback = 0,
  }) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _toInt(
    dynamic value, {
    int fallback = 0,
  }) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _toBool(
    dynamic value, {
    bool fallback = false,
  }) {
    if (value is bool) {
      return value;
    }

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    return fallback;
  }

  String _toStringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    return value.toString();
  }

  Color _parseColor(
    dynamic value, {
    Color fallback = Colors.transparent,
  }) {
    if (value is Color) {
      return value;
    }

    final String text =
        value?.toString().replaceAll('#', '') ?? '';

    if (text.isEmpty) {
      return fallback;
    }

    try {
      if (text.length == 6) {
        return Color(int.parse('FF$text', radix: 16));
      }

      if (text.length == 8) {
        return Color(int.parse(text, radix: 16));
      }
    } catch (_) {}

    return fallback;
  }

  EdgeInsets _parsePadding(
    dynamic value, {
    EdgeInsets fallback = EdgeInsets.zero,
  }) {
    if (value is num) {
      return EdgeInsets.all(value.toDouble());
    }

    if (value is Map) {
      return EdgeInsets.only(
        left: _toDouble(value['left']),
        top: _toDouble(value['top']),
        right: _toDouble(value['right']),
        bottom: _toDouble(value['bottom']),
      );
    }

    return fallback;
  }

  BorderRadius _parseRadius(dynamic value) {
    final radius = _toDouble(value);

    if (radius <= 0) {
      return BorderRadius.zero;
    }

    return BorderRadius.circular(radius);
  }

  // ==============================================================
  // SÉLECTION
  // ==============================================================

  void _selectWidget(String id) {
    setState(() {
      _selectedNodeId = id;
      _inspectorVisible = true;
      _inspectorDragOffset = 0;
    });

    _inspectorAnimationController.forward();
  }

  void _clearSelection() {
    setState(() {
      _selectedNodeId = null;
      _inspectorVisible = false;
      _inspectorDragOffset = 0;
    });

    _inspectorAnimationController.reverse();

    ref.read(editorProvider.notifier).clearSelection();
  }

  void _closeInspector() {
    setState(() {
      _inspectorVisible = false;
      _inspectorDragOffset = 0;
    });

    _inspectorAnimationController.reverse();
  }

  // ==============================================================
  // CRÉATION DES WIDGETS
  // ==============================================================

  WidgetNode? _createDefaultWidget(
    String type,
  ) {
    switch (type) {
      case 'Container':
        return WidgetNode.create(
          type: 'Container',
          properties: <String, dynamic>{
            'color': '#FFFFFFFF',
            'padding': 8,
            'borderRadius': 8,
          },
          children: [],
        );

      case 'Column':
        return WidgetNode.create(
          type: 'Column',
          properties: <String, dynamic>{
            'mainAxisAlignment': 'start',
            'crossAxisAlignment': 'center',
            'mainAxisSize': 'max',
          },
          children: [],
        );

      case 'Row':
        return WidgetNode.create(
          type: 'Row',
          properties: <String, dynamic>{
            'mainAxisAlignment': 'start',
            'crossAxisAlignment': 'center',
            'mainAxisSize': 'max',
          },
          children: [],
        );

      case 'Stack':
        return WidgetNode.create(
          type: 'Stack',
          properties: <String, dynamic>{},
          children: [],
        );

      case 'Center':
        return WidgetNode.create(
          type: 'Center',
          properties: <String, dynamic>{},
          children: [],
        );

      case 'Align':
        return WidgetNode.create(
          type: 'Align',
          properties: <String, dynamic>{
            'alignment': 'center',
          },
          children: [],
        );

      case 'Padding':
        return WidgetNode.create(
          type: 'Padding',
          properties: <String, dynamic>{
            'padding': 12,
          },
          children: [],
        );

      case 'SizedBox':
        return WidgetNode.create(
          type: 'SizedBox',
          properties: <String, dynamic>{
            'width': 100,
            'height': 50,
          },
          children: [],
        );

      case 'Expanded':
        return WidgetNode.create(
          type: 'Expanded',
          properties: <String, dynamic>{
            'flex': 1,
          },
          children: [],
        );

      case 'Flexible':
        return WidgetNode.create(
          type: 'Flexible',
          properties: <String, dynamic>{
            'flex': 1,
          },
          children: [],
        );

      case 'Spacer':
        return WidgetNode.create(
          type: 'Spacer',
          properties: <String, dynamic>{
            'flex': 1,
          },
          children: [],
        );

      case 'Text':
        return WidgetNode.create(
          type: 'Text',
          properties: <String, dynamic>{
            'data': 'Texte',
            'fontSize': 16,
            'color': '#FF202020',
            'fontWeight': 'normal',
            'textAlign': 'left',
          },
        );

      case 'Button':
        return WidgetNode.create(
          type: 'Button',
          properties: <String, dynamic>{
            'text': 'Bouton',
            'buttonType': 'elevated',
            'enabled': true,
          },
        );

      case 'Image':
        return WidgetNode.create(
          type: 'Image',
          properties: <String, dynamic>{
            'src': '',
            'fit': 'cover',
            'width': 100,
            'height': 100,
          },
        );

      case 'Icon':
        return WidgetNode.create(
          type: 'Icon',
          properties: <String, dynamic>{
            'icon': 'star',
            'size': 28,
            'color': '#FFFFD600',
          },
        );

      case 'TextField':
        return WidgetNode.create(
          type: 'TextField',
          properties: <String, dynamic>{
            'hintText': 'Saisir...',
            'labelText': 'Texte',
          },
        );

      case 'Checkbox':
        return WidgetNode.create(
          type: 'Checkbox',
          properties: <String, dynamic>{
            'value': false,
          },
        );

      case 'Switch':
        return WidgetNode.create(
          type: 'Switch',
          properties: <String, dynamic>{
            'value': false,
          },
        );

      case 'Slider':
        return WidgetNode.create(
          type: 'Slider',
          properties: <String, dynamic>{
            'min': 0,
            'max': 100,
            'value': 50,
          },
        );

      case 'ListView':
        return WidgetNode.create(
          type: 'ListView',
          properties: <String, dynamic>{
            'scrollDirection': 'vertical',
          },
          children: [],
        );

      case 'GridView':
        return WidgetNode.create(
          type: 'GridView',
          properties: <String, dynamic>{
            'crossAxisCount': 2,
          },
          children: [],
        );

      case 'ListTile':
        return WidgetNode.create(
          type: 'ListTile',
          properties: <String, dynamic>{
            'title': 'Titre',
            'subtitle': 'Sous-titre',
            'leadingIcon': 'star',
            'trailingIcon': 'chevron_right',
          },
        );

      case 'Wrap':
        return WidgetNode.create(
          type: 'Wrap',
          properties: <String, dynamic>{
            'spacing': 8,
            'runSpacing': 8,
          },
          children: [],
        );

      case 'SingleChildScrollView':
        return WidgetNode.create(
          type: 'SingleChildScrollView',
          properties: <String, dynamic>{},
          children: [],
        );

      case 'SafeArea':
        return WidgetNode.create(
          type: 'SafeArea',
          properties: <String, dynamic>{},
          children: [],
        );

      case 'Card':
        return WidgetNode.create(
          type: 'Card',
          properties: <String, dynamic>{
            'elevation': 2,
            'borderRadius': 12,
          },
          children: [],
        );

      case 'Divider':
        return WidgetNode.create(
          type: 'Divider',
          properties: <String, dynamic>{
            'height': 1,
            'thickness': 1,
          },
        );

      case 'Visibility':
        return WidgetNode.create(
          type: 'Visibility',
          properties: <String, dynamic>{
            'visible': true,
          },
          children: [],
        );

      case 'Opacity':
        return WidgetNode.create(
          type: 'Opacity',
          properties: <String, dynamic>{
            'opacity': 1.0,
          },
          children: [],
        );

      case 'Scaffold':
        return WidgetNode.create(
          type: 'Scaffold',
          properties: <String, dynamic>{},
          children: [],
        );

      case 'AppBar':
        return WidgetNode.create(
          type: 'AppBar',
          properties: <String, dynamic>{
            'title': 'Titre',
          },
        );

      default:
        return null;
    }
  }

  // ==============================================================
  // AJOUT
  // ==============================================================

  void _dropNewWidget({
    required String type,
    required PageModel page,
    String? forcedParentId,
  }) {
    final newWidget = _createDefaultWidget(type);

    if (newWidget == null) {
      _showSnack(
        'Widget "$type" non supporté',
        error: true,
      );
      return;
    }

    final root = page.rootWidget;

    String? parentId = forcedParentId;

    if (parentId == null &&
        _selectedNodeId != null &&
        root != null) {
      final selected = root.findById(_selectedNodeId!);

      if (selected != null &&
          _canHaveChildren(selected)) {
        parentId = selected.id;
      }
    }

    try {
      ref.read(editorProvider.notifier).addWidget(
            newWidget,
            parentId: parentId,
          );

      setState(() {
        _selectedNodeId = newWidget.id;
        _inspectorVisible = true;
        _inspectorDragOffset = 0;
      });

      _inspectorAnimationController.forward();

      _showSnack(
        '$type ajouté',
      );
    } catch (error) {
      _showSnack(
        'Impossible d’ajouter $type : $error',
        error: true,
      );
    }
  }

  // ==============================================================
  // DROP
  // ==============================================================

  void _handleDropOnNode(
    _DesignDragData data,
    WidgetNode target,
    PageModel page,
  ) {
    if (!_canHaveChildren(target)) {
      return;
    }

    _dropNewWidget(
      type: data.type,
      page: page,
      forcedParentId: target.id,
    );
  }

  void _handleDropOnPhone(
    _DesignDragData data,
    PageModel page,
  ) {
    final root = page.rootWidget;

    String? parentId;

    if (_selectedNodeId != null && root != null) {
      final selected = root.findById(_selectedNodeId!);

      if (selected != null &&
          _canHaveChildren(selected)) {
        parentId = selected.id;
      }
    }

    _dropNewWidget(
      type: data.type,
      page: page,
      forcedParentId: parentId,
    );
  }

  // ==============================================================
  // SNACK
  // ==============================================================

  void _showSnack(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1200),
          backgroundColor:
              error ? const Color(0xFFB3261E) : const Color(0xFF17171F),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);

    final PageModel? currentPage = _getCurrentPage();

    if (currentPage == null) {
      return const Scaffold(
        backgroundColor: _background,
        body: Center(
          child: Text(
            'Aucune page disponible.',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    final WidgetNode? rootWidget = currentPage.rootWidget;

    WidgetNode? selectedWidget;

    if (rootWidget != null &&
        _selectedNodeId != null) {
      selectedWidget =
          rootWidget.findById(_selectedNodeId!);
    }

    if (_selectedNodeId != null &&
        selectedWidget == null &&
        editorState.selectedWidgetId != null &&
        rootWidget != null) {
      selectedWidget =
          rootWidget.findById(editorState.selectedWidgetId!);
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _background,
      drawer: _buildSettingsDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildCompactTopBar(),

            Expanded(
              child: Row(
                children: [
                  // ==================================================
                  // PALETTE
                  // ==================================================
                  SizedBox(
                    width: _calculatePaletteWidth(
                      context,
                    ),
                    child: _buildPalette(),
                  ),

                  // ==================================================
                  // CANVAS
                  // ==================================================
                  Expanded(
                    child: LayoutBuilder(
                      builder: (
                        context,
                        constraints,
                      ) {
                        return _buildCanvas(
                          currentPage: currentPage,
                          rootWidget: rootWidget,
                          selectedWidget: selectedWidget,
                          availableSize: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // PALETTE WIDTH
  // ==============================================================

  double _calculatePaletteWidth(
    BuildContext context,
  ) {
    final width = MediaQuery.sizeOf(context).width;

    if (width < 700) {
      return 188;
    }

    if (width < 900) {
      return 205;
    }

    return 220;
  }

  // ==============================================================
  // TOP BAR
  // ==============================================================

  Widget _buildCompactTopBar() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF101015),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          _topActionButton(
            icon: Icons.arrow_back,
            tooltip: 'Retour',
            onPressed: () {
              Navigator.of(context).maybePop();
            },
          ),

          const SizedBox(width: 4),

          _topActionButton(
            icon: Icons.undo_rounded,
            tooltip: 'Annuler',
            onPressed: () {},
            disabled: true,
          ),

          _topActionButton(
            icon: Icons.redo_rounded,
            tooltip: 'Rétablir',
            onPressed: () {},
            disabled: true,
          ),

          const Spacer(),

          _topActionButton(
            icon: Icons.play_arrow_rounded,
            tooltip: 'Prévisualiser',
            onPressed: () {},
            emphasized: true,
          ),

          _topActionButton(
            icon: Icons.download_rounded,
            tooltip: 'Exporter',
            onPressed: () {},
          ),

          _topActionButton(
            icon: Icons.save_rounded,
            tooltip: 'Enregistrer',
            onPressed: () {},
          ),

          _topActionButton(
            icon: Icons.tune_rounded,
            tooltip: 'Réglages',
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
        ],
      ),
    );
  }

  Widget _topActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool disabled = false,
    bool emphasized = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        splashRadius: 22,
        onPressed: disabled ? null : onPressed,
        icon: Icon(
          icon,
          size: 24,
          color: disabled
              ? Colors.white24
              : emphasized
                  ? _cyan
                  : Colors.white70,
        ),
      ),
    );
  }

  // ==============================================================
  // PALETTE
  // ==============================================================

  Widget _buildPalette() {
    final filteredEntries =
        <MapEntry<String, List<_PaletteItem>>>[];

    for (final entry in _widgetCategories.entries) {
      final items = entry.value.where(
        (item) {
          if (_searchQuery.isEmpty) {
            return true;
          }

          return item.type
              .toLowerCase()
              .contains(_searchQuery);
        },
      ).toList();

      if (items.isNotEmpty) {
        filteredEntries.add(
          MapEntry(
            entry.key,
            items,
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: _panel,
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.05),
          ),
        ),
      ),
      child: Column(
        children: [
          // Recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(
              8,
              8,
              8,
              6,
            ),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: _tile,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: Colors.white54,
                  ),
                  hintText: 'Rechercher',
                  hintStyle: const TextStyle(
                    color: Colors.white30,
                    fontSize: 12,
                  ),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          splashRadius: 16,
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white38,
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                        ),
                ),
              ),
            ),
          ),

          // Contenu scrollable
          Expanded(
            child: Scrollbar(
              controller: _paletteScrollController,
              thumbVisibility: true,
              child: ListView(
                controller: _paletteScrollController,
                padding: const EdgeInsets.fromLTRB(
                  7,
                  2,
                  7,
                  90,
                ),
                children: [
                  for (final entry in filteredEntries)
                    _buildPaletteCategory(
                      entry.key,
                      entry.value,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaletteCategory(
    String category,
    List<_PaletteItem> items,
  ) {
    final expanded =
        _expandedCategories.contains(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              if (expanded) {
                _expandedCategories.remove(category);
              } else {
                _expandedCategories.add(category);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 8,
            ),
            child: Row(
              children: [
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 17,
                  color: Colors.white38,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    category.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Text(
                  '${items.length}',
                  style: const TextStyle(
                    color: Colors.white24,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (expanded)
          LayoutBuilder(
            builder: (
              context,
              constraints,
            ) {
              final width = constraints.maxWidth;

              final crossAxisCount =
                  width >= 195 ? 3 : 2;

              return GridView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (
                  context,
                  index,
                ) {
                  return _buildPaletteItem(
                    items[index],
                  );
                },
              );
            },
          ),

        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildPaletteItem(
    _PaletteItem item,
  ) {
    final tile = Container(
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: Colors.white.withOpacity(0.035),
        ),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            item.icon,
            color: item.color,
            size: 20,
          ),
          const SizedBox(height: 5),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              item.type,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return LongPressDraggable<_DesignDragData>(
      data: _DesignDragData(
        type: item.type,
      ),
      dragAnchorStrategy:
          pointerDragAnchorStrategy,
      maxSimultaneousDrags: 1,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF242430),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: _cyan,
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 18,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  color: item.color,
                  size: 25,
                ),
                const SizedBox(height: 2),
                Text(
                  item.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: tile,
      ),
      child: tile,
    );
  }

  // ==============================================================
  // CANVAS
  // ==============================================================

  Widget _buildCanvas({
    required PageModel currentPage,
    required WidgetNode? rootWidget,
    required WidgetNode? selectedWidget,
    required Size availableSize,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: _buildCanvasBackground(
            availableSize,
          ),
        ),

        Positioned.fill(
          child: DragTarget<_DesignDragData>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) {
              _handleDropOnPhone(
                details.data,
                currentPage,
              );
            },
            builder: (
              context,
              candidateData,
              rejectedData,
            ) {
              final hovering =
                  candidateData.isNotEmpty;

              return Center(
                child: _buildResponsivePhone(
                  currentPage: currentPage,
                  rootWidget: rootWidget,
                  hovering: hovering,
                  availableSize: availableSize,
                ),
              );
            },
          ),
        ),

        // Inspecteur
        if (_inspectorVisible &&
            selectedWidget != null)
          _buildFloatingInspector(
            selectedWidget,
          ),

        // Contrôles du canvas
        Positioned(
          right: 12,
          bottom:
              _inspectorVisible ? 328 : 24,
          child: _buildCanvasControls(),
        ),
      ],
    );
  }

  Widget _buildCanvasBackground(
    Size size,
  ) {
    if (!_showGrid) {
      return const ColoredBox(
        color: _background,
      );
    }

    return CustomPaint(
      painter: _GridPainter(),
      child: const ColoredBox(
        color: _background,
      ),
    );
  }

  Widget _buildResponsivePhone({
    required PageModel currentPage,
    required WidgetNode? rootWidget,
    required bool hovering,
    required Size availableSize,
  }) {
    final maxWidth =
        (availableSize.width - 26).clamp(
      150.0,
      420.0,
    );

    final maxHeight =
        (availableSize.height - 20).clamp(
      250.0,
      820.0,
    );

    final widthScale =
        maxWidth / _phoneBaseWidth;

    final heightScale =
        maxHeight / _phoneBaseHeight;

    final scale =
        widthScale < heightScale
            ? widthScale
            : heightScale;

    final phoneWidth =
        _phoneBaseWidth * scale;

    final phoneHeight =
        _phoneBaseHeight * scale;

    return AnimatedContainer(
      duration:
          const Duration(milliseconds: 180),
      width: phoneWidth,
      height: phoneHeight,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius:
            BorderRadius.circular(
          40 * scale.clamp(0.65, 1.0),
        ),
        border: Border.all(
          color: hovering
              ? _cyan
              : const Color(0xFF2A2A35),
          width: hovering ? 3 : 8 * scale,
        ),
        boxShadow: [
          BoxShadow(
            color: hovering
                ? _cyan.withOpacity(0.25)
                : Colors.black.withOpacity(0.55),
            blurRadius: 28,
            spreadRadius: 3,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(
          31 * scale.clamp(0.65, 1.0),
        ),
        child: Column(
          children: [
            _buildPhoneStatusBar(scale),

            Expanded(
              child: ColoredBox(
                color: Colors.white,
                child: rootWidget == null
                    ? _buildEmptyPhoneState()
                    : _EditableNode(
                        node: rootWidget,
                        state: this,
                        parser:
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
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneStatusBar(
    double scale,
  ) {
    return Container(
      height: 31 * scale,
      color: const Color(0xFF101015),
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
      ),
      child: Row(
        children: [
          Text(
            '13:37',
            style: TextStyle(
              color: Colors.white,
              fontSize:
                  11 * scale.clamp(0.75, 1.0),
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            width: 62 * scale,
            height: 15 * scale,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius:
                  BorderRadius.circular(10),
            ),
          ),
          const Spacer(),
          Icon(
            Icons.signal_cellular_4_bar,
            color: Colors.white,
            size:
                12 * scale.clamp(0.75, 1.0),
          ),
          SizedBox(width: 4 * scale),
          Icon(
            Icons.wifi,
            color: Colors.white,
            size:
                12 * scale.clamp(0.75, 1.0),
          ),
          SizedBox(width: 4 * scale),
          Icon(
            Icons.battery_full,
            color: Colors.white,
            size:
                12 * scale.clamp(0.75, 1.0),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPhoneState() {
    return DragTarget<_DesignDragData>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final page = _getCurrentPage();

        if (page == null) return;

        _handleDropOnPhone(
          details.data,
          page,
        );
      },
      builder: (
        context,
        candidateData,
        rejectedData,
      ) {
        final hovering =
            candidateData.isNotEmpty;

        return AnimatedContainer(
          duration:
              const Duration(milliseconds: 150),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hovering
                ? _cyan.withOpacity(0.08)
                : Colors.white,
            border: Border.all(
              color: hovering
                  ? _cyan
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                hovering
                    ? Icons.add_circle
                    : Icons.smartphone,
                size: 42,
                color: hovering
                    ? _cyan
                    : Colors.black26,
              ),
              const SizedBox(height: 10),
              Text(
                hovering
                    ? 'Déposer le widget ici'
                    : 'Glissez un widget ici',
                style: TextStyle(
                  color: hovering
                      ? const Color(
                          0xFF00AFC0,
                        )
                      : Colors.black38,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==============================================================
  // CONTROLES CANVAS
  // ==============================================================

  Widget _buildCanvasControls() {
    return Column(
      children: [
        _roundCanvasButton(
          icon: Icons.add,
          onTap: () {},
        ),
        const SizedBox(height: 8),
        _roundCanvasButton(
          icon: Icons.remove,
          onTap: () {},
        ),
        const SizedBox(height: 8),
        _roundCanvasButton(
          icon: Icons.refresh,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _roundCanvasButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(30),
        onTap: onTap,
        child: Ink(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF6D6D6D)
                .withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white10,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // INSPECTEUR
  // ==============================================================

  Widget _buildFloatingInspector(
    WidgetNode selectedWidget,
  ) {
    final bottomOffset =
        -_inspectorDragOffset.clamp(
          0,
          320,
        );

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomOffset,
      child: FractionallySizedBox(
        widthFactor: 1,
        child: AnimatedBuilder(
          animation: _inspectorAnimation,
          builder: (
            context,
            child,
          ) {
            return Transform.translate(
              offset: Offset(
                0,
                (1 -
                        _inspectorAnimation
                            .value) *
                    330,
              ),
              child: child,
            );
          },
          child: _buildInspectorPanel(
            selectedWidget,
          ),
        ),
      ),
    );
  }

  Widget _buildInspectorPanel(
    WidgetNode selectedWidget,
  ) {
    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(
        top: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 18,
          sigmaY: 18,
        ),
        child: Container(
          height: 318,
          decoration: BoxDecoration(
            color:
                const Color(0xFF15151C)
                    .withOpacity(0.97),
            borderRadius:
                const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white
                    .withOpacity(0.10),
              ),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            children: [
              // ====================================================
              // HEADER INSPECTEUR
              // ====================================================
              GestureDetector(
                behavior:
                    HitTestBehavior.opaque,
                onVerticalDragStart: (_) {
                  setState(() {
                    _inspectorDragOffset = 0;
                  });
                },
                onVerticalDragUpdate:
                    (details) {
                  if (details.delta.dy > 0) {
                    setState(() {
                      _inspectorDragOffset +=
                          details.delta.dy;

                      _inspectorDragOffset =
                          _inspectorDragOffset.clamp(
                        0,
                        330,
                      );
                    });
                  }
                },
                onVerticalDragEnd:
                    (details) {
                  final velocity =
                      details.primaryVelocity ??
                          0;

                  if (_inspectorDragOffset > 90 ||
                      velocity > 650) {
                    _closeInspector();
                  } else {
                    setState(() {
                      _inspectorDragOffset = 0;
                    });
                  }
                },
                child: SizedBox(
                  height: 49,
                  child: Stack(
                    children: [
                      Align(
                        alignment:
                            Alignment.center,
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            Container(
                              width: 44,
                              height: 5,
                              decoration:
                                  BoxDecoration(
                                color: Colors.white24,
                                borderRadius:
                                    BorderRadius
                                        .circular(20),
                              ),
                            ),
                            const SizedBox(
                              height: 7,
                            ),
                            Text(
                              selectedWidget
                                  .type,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 12,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Positioned(
                        right: 4,
                        top: 1,
                        child: IconButton(
                          splashRadius: 20,
                          icon: const Icon(
                            Icons.close,
                            color:
                                Colors.white54,
                            size: 20,
                          ),
                          onPressed:
                              _closeInspector,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(
                color: Colors.white10,
                height: 1,
              ),

              // ====================================================
              // INSPECTEUR
              // ====================================================
              Expanded(
                child: PropertyInspector(
                  key: ValueKey(
                    selectedWidget.id,
                  ),
                  selectedWidget:
                      selectedWidget,
                  onPropertyChanged:
                      (key, value) {
                    ref
                        .read(
                          editorProvider
                              .notifier,
                        )
                        .updateWidgetProperty(
                          selectedWidget.id,
                          key,
                          value,
                        );
                  },
                  onDelete: () {
                    final id =
                        selectedWidget.id;

                    ref
                        .read(
                          editorProvider
                              .notifier,
                        )
                        .removeWidget(id);

                    _clearSelection();
                  },
                  onDuplicate: () {
                    _duplicateWidget(
                      selectedWidget,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // DUPLICATION
  // ==============================================================

  void _duplicateWidget(
    WidgetNode original,
  ) {
    final page = _getCurrentPage();

    if (page == null) return;

    final duplicate =
        _cloneNode(original);

    if (duplicate == null) {
      _showSnack(
        'Duplication impossible',
        error: true,
      );
      return;
    }

    String? parentId;

    final root = page.rootWidget;

    if (root != null) {
      final parent =
          _findParent(root, original.id);

      if (parent != null &&
          _canHaveChildren(parent)) {
        parentId = parent.id;
      }
    }

    try {
      ref
          .read(editorProvider.notifier)
          .addWidget(
            duplicate,
            parentId: parentId,
          );

      setState(() {
        _selectedNodeId =
            duplicate.id;
      });

      _showSnack(
        '${original.type} dupliqué',
      );
    } catch (error) {
      _showSnack(
        'Erreur duplication : $error',
        error: true,
      );
    }
  }

  WidgetNode? _cloneNode(
    WidgetNode original,
  ) {
    try {
      final copy =
          WidgetNode.create(
        type: original.type,
        properties:
            Map<String, dynamic>.from(
          original.properties,
        ),
        children: [],
      );

      if (original.children
          .isNotEmpty) {
        for (final child
            in original.children) {
          final clonedChild =
              _cloneNode(child);

          if (clonedChild != null) {
            copy.children.add(
              clonedChild,
            );
          }
        }
      }

      return copy;
    } catch (_) {
      return null;
    }
  }

  WidgetNode? _findParent(
    WidgetNode root,
    String childId,
  ) {
    for (final child in root.children) {
      if (child.id == childId) {
        return root;
      }

      final result =
          _findParent(
        child,
        childId,
      );

      if (result != null) {
        return result;
      }
    }

    return null;
  }

  // ==============================================================
  // DRAWER
  // ==============================================================

  Widget _buildSettingsDrawer() {
    return Drawer(
      backgroundColor: _panel,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding:
                  const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: _panel2,
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration:
                        const BoxDecoration(
                      color: Colors.cyan,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
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
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Configuration de l’éditeur',
                          style:
                              TextStyle(
                            color:
                                Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _settingsSwitch(
              icon: Icons.grid_on,
              title: 'Afficher la grille',
              value: _showGrid,
              onChanged: (value) {
                setState(() {
                  _showGrid = value;
                });
              },
            ),

            _settingsSwitch(
              icon: Icons.touch_app,
              title: 'Afficher les zones de drop',
              value: _showDropHints,
              onChanged: (value) {
                setState(() {
                  _showDropHints = value;
                });
              },
            ),

            ListTile(
              leading: const Icon(
                Icons.phone_android,
                color: Colors.white70,
              ),
              title: const Text(
                'Téléphone',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              subtitle: const Text(
                'Cadre responsive',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ),

            ListTile(
              leading: const Icon(
                Icons.palette_outlined,
                color: Colors.white70,
              ),
              title: const Text(
                'Thème',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              subtitle: const Text(
                'Sombre néon',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ),

            const Divider(
              color: Colors.white10,
            ),

            ListTile(
              leading: const Icon(
                Icons.cleaning_services,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Réinitialiser',
                style: TextStyle(
                  color: Colors.redAccent,
                ),
              ),
              onTap: () {
                _clearSelection();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool>
        onChanged,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.white70,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

// ==================================================================
// RENDERER ÉDITABLE
// ==================================================================

class _EditableNode extends StatelessWidget {
  final WidgetNode node;
  final _DesignTabState state;
  final JsonWidgetParser parser;

  const _EditableNode({
    required this.node,
    required this.state,
    required this.parser,
  });

  @override
  Widget build(BuildContext context) {
    final selected =
        state._selectedNodeId ==
            node.id;

    final canDrop =
        state._canHaveChildren(node);

    final actual =
        _buildActualWidget(context);

    Widget result = GestureDetector(
      behavior:
          HitTestBehavior.opaque,
      onTap: () {
        state._selectWidget(node.id);
      },
      child: actual,
    );

    if (canDrop) {
      result = DragTarget<_DesignDragData>(
        onWillAcceptWithDetails: (_) {
          return true;
        },
        onAcceptWithDetails: (details) {
          final page =
              state._getCurrentPage();

          if (page == null) {
            return;
          }

          state._handleDropOnNode(
            details.data,
            node,
            page,
          );
        },
        builder: (
          context,
          candidateData,
          rejectedData,
        ) {
          final hovering =
              candidateData.isNotEmpty;

          return AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 100,
            ),
            decoration:
                hovering &&
                        state._showDropHints
                    ? BoxDecoration(
                        border: Border.all(
                          color: const Color(
                            0xFF00E5FF,
                          ),
                          width: 2,
                        ),
                        color: const Color(
                          0xFF00E5FF,
                        ).withOpacity(0.06),
                      )
                    : null,
            child: result,
          );
        },
      );
    }

    return Stack(
      clipBehavior:
          Clip.antiAlias,
      children: [
        result,

        // Bordure de sélection
        if (selected)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(
                      0xFF00E5FF,
                    ),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

        // Étiquette du widget
        if (selected)
          Positioned(
            left: 0,
            top: 0,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                color: const Color(
                  0xFF00B8D4,
                ),
                child: Text(
                  node.type,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 8,
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

  Widget _buildActualWidget(
    BuildContext context,
  ) {
    final children =
        <Widget>[
      for (final child
          in node.children)
        _EditableNode(
          node: child,
          state: state,
          parser: parser,
        ),
    ];

    final p = node.properties;

    switch (node.type) {
      // ==========================================================
      // CONTAINER
      // ==========================================================

      case 'Container':
        return Container(
          width: p['width'] == null
              ? null
              : state._toDouble(
                  p['width'],
                ),
          height: p['height'] == null
              ? null
              : state._toDouble(
                  p['height'],
                ),
          padding:
              state._parsePadding(
            p['padding'],
          ),
          margin:
              state._parsePadding(
            p['margin'],
          ),
          alignment:
              _alignmentFromString(
            p['alignment'],
          ),
          decoration:
              BoxDecoration(
            color: state._parseColor(
              p['color'],
              fallback:
                  Colors.transparent,
            ),
            borderRadius:
                state._parseRadius(
              p['borderRadius'],
            ),
          ),
          child: _singleChild(
            children,
          ),
        );

      // ==========================================================
      // COLUMN
      // ==========================================================

      case 'Column':
        return Column(
          mainAxisSize:
              p['mainAxisSize'] ==
                      'min'
                  ? MainAxisSize.min
                  : MainAxisSize.max,
          mainAxisAlignment:
              _mainAxisAlignment(
            p['mainAxisAlignment'],
          ),
          crossAxisAlignment:
              _crossAxisAlignment(
            p['crossAxisAlignment'],
          ),
          children: children,
        );

      // ==========================================================
      // ROW
      // ==========================================================

      case 'Row':
        return Row(
          mainAxisSize:
              p['mainAxisSize'] ==
                      'min'
                  ? MainAxisSize.min
                  : MainAxisSize.max,
          mainAxisAlignment:
              _mainAxisAlignment(
            p['mainAxisAlignment'],
          ),
          crossAxisAlignment:
              _crossAxisAlignment(
            p['crossAxisAlignment'],
          ),
          children: children,
        );

      // ==========================================================
      // STACK
      // ==========================================================

      case 'Stack':
        return Stack(
          clipBehavior:
              Clip.none,
          children: children,
        );

      // ==========================================================
      // CENTER
      // ==========================================================

      case 'Center':
        return Center(
          child: _singleChild(
            children,
          ),
        );

      // ==========================================================
      // ALIGN
      // ==========================================================

      case 'Align':
        return Align(
          alignment:
              _alignmentFromString(
            p['alignment'],
          ),
          child: _singleChild(
            children,
          ),
        );

      // ==========================================================
      // PADDING
      // ==========================================================

      case 'Padding':
        return Padding(
          padding:
              state._parsePadding(
            p['padding'],
            fallback:
                const EdgeInsets.all(8),
          ),
          child: _singleChild(
            children,
          ),
        );

      // ==========================================================
      // SIZED BOX
      // ==========================================================

      case 'SizedBox':
        return SizedBox(
          width: p['width'] == null
              ? null
              : state._toDouble(
                  p['width'],
                ),
          height: p['height'] == null
              ? null
              : state._toDouble(
                  p['height'],
                ),
          child: _singleChild(
            children,
          ),
        );

      // ==========================================================
      // EXPANDED
      // ==========================================================

      case 'Expanded':
        return Expanded(
          flex: state._toInt(
            p['flex'],
            fallback: 1,
          ),
          child:
              _singleChild(
            children,
          ),
        );

      // ==========================================================
      // FLEXIBLE
      // ==========================================================

      case 'Flexible':
        return Flexible(
          flex: state._toInt(
            p['flex'],
            fallback: 1,
          ),
          child:
              _singleChild(
            children,
          ),
        );

      // ==========================================================
      // SPACER
      // ==========================================================

      case 'Spacer':
        return Spacer(
          flex: state._toInt(
            p['flex'],
            fallback: 1,
          ),
        );

      // ==========================================================
      // TEXT
      // ==========================================================

      case 'Text':
        return Text(
          state._toStringValue(
            p['data'],
            fallback: 'Texte',
          ),
          textAlign:
              _textAlign(
            p['textAlign'],
          ),
          style: TextStyle(
            fontSize:
                state._toDouble(
              p['fontSize'],
              fallback: 16,
            ),
            color:
                state._parseColor(
              p['color'],
              fallback:
                  Colors.black,
            ),
            fontWeight:
                _fontWeight(
              p['fontWeight'],
            ),
          ),
        );

      // ==========================================================
      // BUTTON
      // ==========================================================

      case 'Button':
        final text =
            state._toStringValue(
          p['text'],
          fallback: 'Bouton',
        );

        final buttonType =
            state._toStringValue(
          p['buttonType'],
          fallback: 'elevated',
        );

        final enabled =
            state._toBool(
          p['enabled'],
          fallback: true,
        );

        final child =
            Text(text);

        Widget button;

        switch (buttonType) {
          case 'text':
            button = TextButton(
              onPressed:
                  enabled ? () {} : null,
              child: child,
            );
            break;

          case 'outlined':
            button = OutlinedButton(
              onPressed:
                  enabled ? () {} : null,
              child: child,
            );
            break;

          default:
            button = ElevatedButton(
              onPressed:
                  enabled ? () {} : null,
              child: child,
            );
        }

        return IgnorePointer(
          ignoring: true,
          child: button,
        );

      // ==========================================================
      // ICON
      // ==========================================================

      case 'Icon':
        return Icon(
          _iconFromName(
            state._toStringValue(
              p['icon'],
              fallback: 'star',
            ),
          ),
          size:
              state._toDouble(
            p['size'],
            fallback: 28,
          ),
          color:
              state._parseColor(
            p['color'],
            fallback:
                Colors.amber,
          ),
        );

      // ==========================================================
      // IMAGE
      // ==========================================================

      case 'Image':
        return _buildImage(
          context,
          p,
        );

      // ==========================================================
      // TEXT FIELD
      // ==========================================================

      case 'TextField':
        return AbsorbPointer(
          absorbing: true,
          child: TextField(
            decoration: InputDecoration(
              hintText:
                  p['hintText']
                      ?.toString(),
              labelText:
                  p['labelText']
                      ?.toString(),
              border:
                  const OutlineInputBorder(),
            ),
          ),
        );

      // ==========================================================
      // CHECKBOX
      // ==========================================================

      case 'Checkbox':
        return IgnorePointer(
          child: Checkbox(
            value:
                state._toBool(
              p['value'],
            ),
            onChanged: (_) {},
          ),
        );

      // ==========================================================
      // SWITCH
      // ==========================================================

      case 'Switch':
        return IgnorePointer(
          child: Switch(
            value:
                state._toBool(
              p['value'],
            ),
            onChanged: (_) {},
          ),
        );

      // ==========================================================
      // SLIDER
      // ==========================================================

      case 'Slider':
        return IgnorePointer(
          child: Slider(
            min:
                state._toDouble(
              p['min'],
              fallback: 0,
            ),
            max:
                state._toDouble(
              p['max'],
              fallback: 100,
            ),
            value:
                state._toDouble(
              p['value'],
              fallback: 50,
            ).clamp(
              state._toDouble(
                p['min'],
                fallback: 0,
              ),
              state._toDouble(
                p['max'],
                fallback: 100,
              ),
            ),
            onChanged: (_) {},
          ),
        );

      // ==========================================================
      // LIST VIEW
      // ==========================================================

      case 'ListView':
        return ListView(
          physics:
              const NeverScrollableScrollPhysics(),
          children: children,
        );

      // ==========================================================
      // GRID VIEW
      // ==========================================================

      case 'GridView':
        return GridView.count(
          physics:
              const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount:
              state._toInt(
            p['crossAxisCount'],
            fallback: 2,
          ).clamp(1, 6),
          children: children,
        );

      // ==========================================================
      // LIST TILE
      // ==========================================================

      case 'ListTile':
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 10,
          ),
          leading: Icon(
            _iconFromName(
              state._toStringValue(
                p['leadingIcon'],
                fallback: 'star',
              ),
            ),
          ),
          title: Text(
            state._toStringValue(
              p['title'],
              fallback: 'Titre',
            ),
          ),
          subtitle: Text(
            state._toStringValue(
              p['subtitle'],
              fallback: 'Sous-titre',
            ),
          ),
          trailing: Icon(
            _iconFromName(
              state._toStringValue(
                p['trailingIcon'],
                fallback:
                    'chevron_right',
              ),
            ),
          ),
        );

      // ==========================================================
      // WRAP
      // ==========================================================

      case 'Wrap':
        return Wrap(
          spacing:
              state._toDouble(
            p['spacing'],
            fallback: 8,
          ),
          runSpacing:
              state._toDouble(
            p['runSpacing'],
            fallback: 8,
          ),
          children: children,
        );

      // ==========================================================
      // SAFE AREA
      // ==========================================================

      case 'SafeArea':
        return SafeArea(
          child:
              _singleChild(
            children,
          ),
        );

      // ==========================================================
      // SINGLE CHILD SCROLL
      // ==========================================================

      case 'SingleChildScrollView':
        return SingleChildScrollView(
          physics:
              const NeverScrollableScrollPhysics(),
          child:
              _singleChild(
            children,
          ),
        );

      // ==========================================================
      // CARD
      // ==========================================================

      case 'Card':
        return Card(
          margin:
              const EdgeInsets.all(6),
          elevation:
              state._toDouble(
            p['elevation'],
            fallback: 2,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              state._toDouble(
                p['borderRadius'],
                fallback: 12,
              ),
            ),
          ),
          child:
              _singleChild(
            children,
          ),
        );

      // ==========================================================
      // DIVIDER
      // ==========================================================

      case 'Divider':
        return Divider(
          height:
              state._toDouble(
            p['height'],
            fallback: 1,
          ),
          thickness:
              state._toDouble(
            p['thickness'],
            fallback: 1,
          ),
        );

      // ==========================================================
      // VISIBILITY
      // ==========================================================

      case 'Visibility':
        return Visibility(
          visible:
              state._toBool(
            p['visible'],
            fallback: true,
          ),
          child:
              _singleChild(
            children,
          ),
        );

      // ==========================================================
      // OPACITY
      // ==========================================================

      case 'Opacity':
        return Opacity(
          opacity:
              state._toDouble(
            p['opacity'],
            fallback: 1,
          ).clamp(0, 1),
          child:
              _singleChild(
            children,
          ),
        );

      // ==========================================================
      // SCAFFOLD
      // ==========================================================

      case 'Scaffold':
        return Container(
          color: Colors.white,
          child:
              _singleChild(
            children,
          ),
        );

      // ==========================================================
      // APP BAR
      // ==========================================================

      case 'AppBar':
        return Container(
          height: 56,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          color: const Color(
            0xFF1976D2,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              state._toStringValue(
                p['title'],
                fallback: 'Titre',
              ),
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize: 18,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        );

      // ==========================================================
      // FALLBACK PARSER
      // ==========================================================

      default:
        try {
          return parser.build(node);
        } catch (_) {
          return Container(
            padding:
                const EdgeInsets.all(10),
            decoration:
                BoxDecoration(
              color:
                  Colors.red.withOpacity(
                0.08,
              ),
              border:
                  Border.all(
                color:
                    Colors.redAccent,
              ),
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
            ),
            child: Text(
              node.type,
              style:
                  const TextStyle(
                color:
                    Colors.redAccent,
                fontSize: 11,
              ),
            ),
          );
        }
    }
  }

  // ==============================================================
  // IMAGE
  // ==============================================================

  Widget _buildImage(
    BuildContext context,
    Map properties,
  ) {
    final src =
        properties['src']
            ?.toString() ??
            '';

    final width =
        properties['width'] == null
            ? 100.0
            : state._toDouble(
                properties['width'],
              );

    final height =
        properties['height'] == null
            ? 100.0
            : state._toDouble(
                properties['height'],
              );

    if (src.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration:
            BoxDecoration(
          color:
              const Color(0xFFE9E9ED),
          borderRadius:
              BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            color: Colors.black38,
            size: 34,
          ),
        ),
      );
    }

    if (src.startsWith('http://') ||
        src.startsWith('https://')) {
      return Image.network(
        src,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) {
          return Container(
            width: width,
            height: height,
            color:
                Colors.grey.shade200,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Colors.black38,
            ),
          );
        },
      );
    }

    return Image.asset(
      src,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder:
          (_, __, ___) {
        return Container(
          width: width,
          height: height,
          color:
              Colors.grey.shade200,
          child: const Icon(
            Icons.broken_image_outlined,
            color: Colors.black38,
          ),
        );
      },
    );
  }

  Widget _singleChild(
    List<Widget> children,
  ) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return children.first;
  }

  // ==============================================================
  // ENUM HELPERS
  // ==============================================================

  MainAxisAlignment _mainAxisAlignment(
    dynamic value,
  ) {
    switch (value?.toString()) {
      case 'center':
        return MainAxisAlignment.center;
      case 'end':
        return MainAxisAlignment.end;
      case 'spaceBetween':
        return MainAxisAlignment.spaceBetween;
      case 'spaceAround':
        return MainAxisAlignment.spaceAround;
      case 'spaceEvenly':
        return MainAxisAlignment.spaceEvenly;
      default:
        return MainAxisAlignment.start;
    }
  }

  CrossAxisAlignment _crossAxisAlignment(
    dynamic value,
  ) {
    switch (value?.toString()) {
      case 'start':
        return CrossAxisAlignment.start;
      case 'end':
        return CrossAxisAlignment.end;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      default:
        return CrossAxisAlignment.center;
    }
  }

  TextAlign _textAlign(
    dynamic value,
  ) {
    switch (value?.toString()) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  FontWeight _fontWeight(
    dynamic value,
  ) {
    switch (value?.toString()) {
      case 'bold':
        return FontWeight.bold;
      case 'w600':
        return FontWeight.w600;
      case 'w500':
        return FontWeight.w500;
      default:
        return FontWeight.normal;
    }
  }

  Alignment _alignmentFromString(
    dynamic value,
  ) {
    switch (value?.toString()) {
      case 'topLeft':
        return Alignment.topLeft;
      case 'topCenter':
        return Alignment.topCenter;
      case 'topRight':
        return Alignment.topRight;
      case 'centerLeft':
        return Alignment.centerLeft;
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

  IconData _iconFromName(
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
        return Icons.favorite;
      case 'heart':
        return Icons.favorite;
      case 'person':
        return Icons.person;
      case 'star':
        return Icons.star;
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
      case 'more_vert':
        return Icons.more_vert;
      case 'play_arrow':
        return Icons.play_arrow;
      case 'pause':
        return Icons.pause;
      case 'info':
        return Icons.info;
      case 'warning':
        return Icons.warning;
      default:
        return Icons.widgets;
    }
  }
}

// ==================================================================
// GRID PAINTER
// ==================================================================

class _GridPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    const step = 24.0;

    final paint = Paint()
      ..color = Colors.white.withOpacity(
        0.025,
      )
      ..strokeWidth = 1;

    for (
      double x = 0;
      x <= size.width;
      x += step
    ) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (
      double y = 0;
      y <= size.height;
      y += step
    ) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _GridPainter oldDelegate,
  ) {
    return false;
  }
}