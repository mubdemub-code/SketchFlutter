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
// L'ancien WidgetPalette est ignoré ici car nous avons intégré une version Next-Gen directement dans ce fichier.
// import '../widgets/widget_palette.dart'; 

/// Onglet Design de l'éditeur (Version Next-Gen).
class DesignTab extends ConsumerWidget {
  final ProjectModel project;

  const DesignTab({
    super.key,
    required this.project,
  });

  /// Ajoute un nouveau widget à la page courante.
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
              selected.type == 'Scaffold')) {
        parentId = selectedWidgetId;
      }
    }

    editorNotifier.addWidget(newWidget, parentId: parentId);
  }

  /// Crée un [WidgetNode] avec des propriétés par défaut.
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
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorProvider);
    final currentPageId = editorState.currentPageId;
    final selectedWidgetId = editorState.selectedWidgetId;

    // 1. Recherche de la page courante
    PageModel? currentPage;
    for (final page in project.pages) {
      if (page.id == currentPageId) {
        currentPage = page;
        break;
      }
    }
    if (currentPage == null && project.pages.isNotEmpty) {
      currentPage = project.pages.first;
    }

    if (currentPage == null) {
      return Center(
        child: Text(
          'Aucune page. Ajoutez une page dans l\'onglet Pages.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
      );
    }

    final rootWidget = currentPage.rootWidget;
    WidgetNode? selectedWidget;
    if (selectedWidgetId != null && rootWidget != null) {
      selectedWidget = rootWidget.findById(selectedWidgetId);
    }

    // 2. Initialisation du moteur de rendu
    final renderContext = RenderContext(
      project: project,
      variables: const <String, dynamic>{},
    );
    final parser = JsonWidgetParser(context: renderContext);

    Widget previewWidget;
    if (rootWidget != null) {
      try {
        previewWidget = parser.build(rootWidget);
      } catch (error, stackTrace) {
        debugPrint('Erreur lors du rendu : $error');
        previewWidget = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text('Erreur de rendu', style: const TextStyle(color: Colors.white)),
            ],
          ),
        );
      }
    } else {
      previewWidget = const Center(
        child: Text(
          'Glissez un widget ici',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    // 3. Construction de l'interface Next-Gen
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12), // Fond ultra dark moderne
      body: Stack(
        children: [
          // L'espace de travail global (Palette + Canvas)
          Row(
            children: [
              // PALETTE LATÉRALE (Façon Sketchware / Figma)
              _buildModernSidePalette(
                context,
                onWidgetSelected: (type) {
                  _addWidgetToPage(context, ref, type, currentPage, rootWidget, selectedWidgetId);
                },
              ),

              // CANEVAS CENTRAL
              Expanded(
                child: CanvasArea(
                  onBackgroundTap: () {
                    ref.read(editorProvider.notifier).clearSelection();
                  },
                  // La maquette de téléphone
                  child: Center(
                    child: _buildPhoneMockup(previewWidget),
                  ),
                ),
              ),
            ],
          ),

          // PANNEAU PROPRIÉTÉS FLOTTANT (Glassmorphism)
          if (selectedWidget != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildFloatingInspector(context, ref, selectedWidget),
            ),
        ],
      ),
    );
  }

  /// Construit la maquette du téléphone pour sublimer l'aperçu
  Widget _buildPhoneMockup(Widget child) {
    return Container(
      width: 350,
      height: 700,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0xFF2A2A35), width: 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: Colors.cyan.withOpacity(0.05),
            blurRadius: 50,
            spreadRadius: -10,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Le rendu réel de l'application
            SizedBox.expand(child: child),
            
            // L'encoche du téléphone (Dynamic Island stylisé)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: 100,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit une barre latérale élégante pour les widgets
  Widget _buildModernSidePalette(BuildContext context, {required Function(String) onWidgetSelected}) {
    final widgets = [
      {'type': 'Container', 'icon': Icons.crop_din, 'color': Colors.blueAccent},
      {'type': 'Column', 'icon': Icons.view_column, 'color': Colors.indigoAccent},
      {'type': 'Row', 'icon': Icons.table_rows, 'color': Colors.indigoAccent},
      {'type': 'Text', 'icon': Icons.text_fields, 'color': Colors.orangeAccent},
      {'type': 'Button', 'icon': Icons.smart_button, 'color': Colors.greenAccent},
      {'type': 'Image', 'icon': Icons.image, 'color': Colors.purpleAccent},
      {'type': 'Icon', 'icon': Icons.star, 'color': Colors.yellowAccent},
      {'type': 'TextField', 'icon': Icons.input, 'color': Colors.pinkAccent},
    ];

    return Container(
      width: 85,
      decoration: BoxDecoration(
        color: const Color(0xFF181820),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 20),
        itemCount: widgets.length,
        itemBuilder: (context, index) {
          final w = widgets[index];
          return GestureDetector(
            onTap: () => onWidgetSelected(w['type'] as String),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(w['icon'] as IconData, color: w['color'] as Color, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    w['type'] as String,
                    style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Construit l'inspecteur contextuel avec effet Glassmorphism
  Widget _buildFloatingInspector(BuildContext context, WidgetRef ref, WidgetNode selectedWidget) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24).withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Poignée de "Drag" visuelle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              
              // L'inspecteur de propriétés existant
              Expanded(
                child: PropertyInspector(
                  selectedWidget: selectedWidget,
                  onPropertyChanged: (key, value) {
                    ref.read(editorProvider.notifier).updateWidgetProperty(selectedWidget.id, key, value);
                  },
                  onDelete: () {
                    ref.read(editorProvider.notifier).removeWidget(selectedWidget.id);
                  },
                  onDuplicate: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Duplication à venir')),
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
}
