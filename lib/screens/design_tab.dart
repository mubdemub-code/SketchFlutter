import 'dart:ui';
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

/// Onglet Design Studio (Version Next-Gen avec Drag & Drop & Grille 3 colonnes).
class DesignTab extends ConsumerStatefulWidget {
  final ProjectModel project;

  const DesignTab({
    super.key,
    required this.project,
  });

  @override
  ConsumerState<DesignTab> createState() => _DesignTabState();
}

class _DesignTabState extends ConsumerState<DesignTab> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Catégories de widgets avec leurs éléments (Style FlutterFlow)
  final Map<String, List<Map<String, dynamic>>> _widgetCategories = {
    'Structure': [
      {'type': 'Container', 'icon': Icons.crop_din, 'color': Colors.blueAccent},
      {'type': 'Column', 'icon': Icons.view_column, 'color': Colors.indigoAccent},
      {'type': 'Row', 'icon': Icons.table_rows, 'color': Colors.indigoAccent},
      {'type': 'Scaffold', 'icon': Icons.web, 'color': Colors.tealAccent},
      {'type': 'SizedBox', 'icon': Icons.check_box_outline_blank, 'color': Colors.grey},
      {'type': 'Center', 'icon': Icons.center_focus_strong, 'color': Colors.cyanAccent},
    ],
    'Basique': [
      {'type': 'Text', 'icon': Icons.text_fields, 'color': Colors.orangeAccent},
      {'type': 'Button', 'icon': Icons.smart_button, 'color': Colors.greenAccent},
      {'type': 'Image', 'icon': Icons.image, 'color': Colors.purpleAccent},
      {'type': 'Icon', 'icon': Icons.star, 'color': Colors.yellowAccent},
    ],
    'Formulaires': [
      {'type': 'TextField', 'icon': Icons.input, 'color': Colors.pinkAccent},
      {'type': 'Checkbox', 'icon': Icons.check_box, 'color': Colors.lightGreenAccent},
      {'type': 'Switch', 'icon': Icons.toggle_on, 'color': Colors.deepOrangeAccent},
      {'type': 'Slider', 'icon': Icons.linear_scale, 'color': Colors.amberAccent},
    ],
    'Listes': [
      {'type': 'ListView', 'icon': Icons.format_list_bulleted, 'color': Colors.blueGrey},
      {'type': 'GridView', 'icon': Icons.grid_view, 'color': Colors.deepPurpleAccent},
      {'type': 'ListTile', 'icon': Icons.list_alt, 'color': Colors.lightBlueAccent},
    ],
  };

  /// Ajoute un widget cible à la page ou dans le parent sélectionné
  void _addWidgetToPage(
    String type,
    PageModel? currentPage,
    WidgetNode? rootWidget,
    String? selectedWidgetId,
  ) {
    if (currentPage == null) return;

    final editorNotifier = ref.read(editorProvider.notifier);
    final newWidget = _createDefaultWidget(type);

    if (newWidget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Type de widget non supporté : $type')),
      );
      return;
    }

    String? parentId;
    if (selectedWidgetId != null && rootWidget != null) {
      final selected = rootWidget.findById(selectedWidgetId);
      if (selected != null &&
          (selected.type == 'Column' ||
              selected.type == 'Row' ||
              selected.type == 'Container' ||
              selected.type == 'Scaffold' ||
              selected.type == 'ListView' ||
              selected.type == 'GridView')) {
        parentId = selectedWidgetId;
      }
    }

    editorNotifier.addWidget(newWidget, parentId: parentId);
  }

  /// Instanciation d'un WidgetNode par défaut
  WidgetNode? _createDefaultWidget(String type) {
    switch (type) {
      case 'Container':
        return WidgetNode.create(type: 'Container', properties: {'color': '#FFFFFFFF'});
      case 'Text':
        return WidgetNode.create(type: 'Text', properties: {'data': 'Texte', 'fontSize': 16});
      case 'Row':
        return WidgetNode.create(type: 'Row');
      case 'Column':
        return WidgetNode.create(type: 'Column');
      case 'Button':
        return WidgetNode.create(type: 'Button', properties: {'text': 'Bouton', 'buttonType': 'elevated'});
      case 'Image':
        return WidgetNode.create(type: 'Image', properties: {'src': ''});
      case 'Icon':
        return WidgetNode.create(type: 'Icon', properties: {'icon': 'star', 'size': 24});
      case 'TextField':
        return WidgetNode.create(type: 'TextField', properties: {'hintText': 'Saisir...'});
      case 'Checkbox':
        return WidgetNode.create(type: 'Checkbox', properties: {'value': false});
      case 'Switch':
        return WidgetNode.create(type: 'Switch', properties: {'value': false});
      case 'Slider':
        return WidgetNode.create(type: 'Slider', properties: {'min': 0, 'max': 100, 'value': 50});
      case 'ListView':
        return WidgetNode.create(type: 'ListView', children: []);
      case 'GridView':
        return WidgetNode.create(type: 'GridView', children: []);
      case 'ListTile':
        return WidgetNode.create(type: 'ListTile', properties: {'title': 'Titre', 'subtitle': 'Sous-titre'});
      case 'Scaffold':
        return WidgetNode.create(type: 'Scaffold');
      case 'AppBar':
        return WidgetNode.create(type: 'AppBar', properties: {'title': 'Titre'});
      case 'SizedBox':
        return WidgetNode.create(type: 'SizedBox');
      case 'Padding':
        return WidgetNode.create(type: 'Padding');
      case 'Center':
        return WidgetNode.create(type: 'Center');
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final currentPageId = editorState.currentPageId;
    final selectedWidgetId = editorState.selectedWidgetId;

    PageModel? currentPage;
    for (final page in widget.project.pages) {
      if (page.id == currentPageId) {
        currentPage = page;
        break;
      }
    }
    if (currentPage == null && widget.project.pages.isNotEmpty) {
      currentPage = widget.project.pages.first;
    }

    if (currentPage == null) {
      return const Center(
        child: Text('Aucune page disponible.', style: TextStyle(color: Colors.white70)),
      );
    }

    final rootWidget = currentPage.rootWidget;
    WidgetNode? selectedWidget;
    if (selectedWidgetId != null && rootWidget != null) {
      selectedWidget = rootWidget.findById(selectedWidgetId);
    }

    final renderContext = RenderContext(
      project: widget.project,
      variables: const <String, dynamic>{},
    );
    final parser = JsonWidgetParser(context: renderContext);

    Widget previewWidget;
    if (rootWidget != null) {
      try {
        previewWidget = parser.build(rootWidget);
      } catch (error) {
        previewWidget = const Center(
          child: Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
        );
      }
    } else {
      previewWidget = const Center(
        child: Text('Glissez un widget ici', style: TextStyle(color: Colors.white38, fontSize: 16)),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF09090D),
      endDrawer: _buildSettingsDrawer(context),
      body: SafeArea(
        child: Column(
          children: [
            // BARRE SUPERIEURE AVEC PARAMETRES (Drawer Toggle)
            _buildTopBar(context),

            // CONTENU PRINCIPAL
            Expanded(
              child: Stack(
                children: [
                  Row(
                    children: [
                      // PALETTE DE WIDGETS EN GRILLE (3 COLONNES)
                      _buildCategorizedPalette(),

                      // Espace Canva avec le téléphone récepteur Drag & Drop
                      Expanded(
                        child: CanvasArea(
                          onBackgroundTap: () {
                            ref.read(editorProvider.notifier).clearSelection();
                          },
                          child: Center(
                            child: _buildPhoneDropTarget(
                              child: previewWidget,
                              currentPage: currentPage,
                              rootWidget: rootWidget,
                              selectedWidgetId: selectedWidgetId,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // INSPECTEUR RÉTRACTABLE
                  if (selectedWidget != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: GestureDetector(
                        onVerticalDragEnd: (details) {
                          if (details.primaryVelocity! > 200) {
                            ref.read(editorProvider.notifier).clearSelection();
                          }
                        },
                        child: _buildFloatingInspector(context, selectedWidget),
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

  /// Barre supérieure
  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.design_services, color: Colors.cyanAccent, size: 20),
              SizedBox(width: 8),
              Text('Design Studio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white70),
            tooltip: 'Réglages du projet',
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
    );
  }

  /// Palette latérale en Grille 3 Colonnes par catégories
  Widget _buildCategorizedPalette() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        children: _widgetCategories.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
                child: Text(
                  entry.key.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.85,
                ),
                itemCount: entry.value.length,
                itemBuilder: (context, index) {
                  final item = entry.value[index];
                  final String type = item['type'];
                  final IconData icon = item['icon'];
                  final Color color = item['color'];

                  final tileWidget = Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A24),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.03)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: color, size: 22),
                        const SizedBox(height: 4),
                        Text(
                          type,
                          style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );

                  return Draggable<String>(
                    data: type,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFF252533),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                          border: Border.all(color: Colors.cyanAccent),
                        ),
                        child: Icon(icon, color: color, size: 28),
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: 0.3, child: tileWidget),
                    child: tileWidget,
                  );
                },
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Cible DragTarget englobant la maquette du téléphone
  Widget _buildPhoneDropTarget({
    required Widget child,
    required PageModel? currentPage,
    required WidgetNode? rootWidget,
    required String? selectedWidgetId,
  }) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        _addWidgetToPage(details.data, currentPage, rootWidget, selectedWidgetId);
      },
      builder: (context, candidateData, rejectedData) {
        final bool isHovered = candidateData.isNotEmpty;
        return Container(
          width: 350,
          height: 700,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: isHovered ? Colors.cyanAccent : const Color(0xFF2A2A35),
              width: isHovered ? 4 : 12,
            ),
            boxShadow: [
              BoxShadow(
                color: isHovered ? Colors.cyanAccent.withOpacity(0.3) : Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              children: [
                // STATUS BAR DE TÉLÉPHONE IMMUTABLE (Non éditable)
                Container(
                  height: 32,
                  color: const Color(0xFF101015),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '13:37',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        width: 70,
                        height: 16,
                        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
                      ),
                      Row(
                        children: const [
                          Icon(Icons.signal_cellular_4_bar, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Icon(Icons.wifi, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Icon(Icons.battery_full, color: Colors.white, size: 12),
                        ],
                      ),
                    ],
                  ),
                ),

                // ZONE INTERACTIVE DU WIDGET RACINE
                Expanded(child: SizedBox.expand(child: child)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Inspecteur de propriétés avec fermeture tactile
  Widget _buildFloatingInspector(BuildContext context, WidgetNode selectedWidget) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 310,
          decoration: BoxDecoration(
            color: const Color(0xFF17171E).withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Column(
            children: [
              // Poignée de déplacement et fermeture
              Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () {
                        ref.read(editorProvider.notifier).clearSelection();
                      },
                    ),
                  ),
                ],
              ),
              Expanded(
                child: PropertyInspector(
                  selectedWidget: selectedWidget,
                  onPropertyChanged: (key, value) {
                    ref.read(editorProvider.notifier).updateWidgetProperty(selectedWidget.id, key, value);
                  },
                  onDelete: () {
                    ref.read(editorProvider.notifier).removeWidget(selectedWidget.id);
                  },
                  onDuplicate: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Drawer de Réglages Style Sketchware Pro
  Widget _buildSettingsDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF13131A),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1A1A24)),
            child: Column(
              crossAxisAlignment: CrossAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.settings, color: Colors.cyanAccent, size: 36),
                SizedBox(height: 10),
                Text('Options du Canvas', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Configuration du projet & rendu', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.grid_on, color: Colors.white70),
            title: const Text('Afficher la grille', style: TextStyle(color: Colors.white)),
            trailing: Switch(value: true, onChanged: (v) {}),
          ),
          ListTile(
            leading: const Icon(Icons.phonelink_setup, color: Colors.white70),
            title: const Text('Dimensions du cadre', style: TextStyle(color: Colors.white)),
            subtitle: const Text('350 x 700 (iPhone 15)', style: TextStyle(color: Colors.white38, fontSize: 11)),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined, color: Colors.white70),
            title: const Text('Thème de l\'éditeur', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Sombre néon', style: TextStyle(color: Colors.white38, fontSize: 11)),
            onTap: () {},
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.redAccent),
            title: const Text('Réinitialiser la page', style: TextStyle(color: Colors.redAccent)),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
