import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../models/widget_node.dart';

/// Vue arborescente des widgets d'une page.
///
/// Affiche la hiérarchie des widgets sous forme d'arbre dépliable.
/// Chaque nœud affiche une icône représentant son type, son nom de type et son ID.
/// L'utilisateur peut :
///   - sélectionner un widget (tap simple),
///   - étendre/réduire les nœuds parents,
///   - ouvrir un menu contextuel (clic long ou bouton) pour :
///       * sélectionner,
///       * dupliquer,
///       * supprimer,
///       * monter/déplacer vers le haut,
///       * descendre/déplacer vers le bas.
///
/// Une barre de recherche permet de filtrer les widgets par type ou ID.
/// Ce widget est conçu pour être placé dans un panneau latéral de l'onglet Design.
class WidgetTreeView extends StatefulWidget {
  /// Racine de l'arbre des widgets.
  final WidgetNode root;

  /// Identifiant du widget actuellement sélectionné.
  final String? selectedWidgetId;

  /// Callback appelé lorsque l'utilisateur sélectionne un widget.
  final ValueChanged<String?> onSelect;

  /// Callback appelé pour supprimer un widget (reçoit l'ID).
  final ValueChanged<String> onDelete;

  /// Callback appelé pour dupliquer un widget (reçoit l'ID).
  final ValueChanged<String> onDuplicate;

  /// Callback appelé pour déplacer un widget vers le haut (reçoit l'ID).
  final ValueChanged<String>? onMoveUp;

  /// Callback appelé pour déplacer un widget vers le bas (reçoit l'ID).
  final ValueChanged<String>? onMoveDown;

  const WidgetTreeView({
    super.key,
    required this.root,
    required this.selectedWidgetId,
    required this.onSelect,
    required this.onDelete,
    required this.onDuplicate,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  State<WidgetTreeView> createState() => _WidgetTreeViewState();
}

class _WidgetTreeViewState extends State<WidgetTreeView> {
  /// Contrôleur de la barre de recherche.
  final TextEditingController _searchController = TextEditingController();

  /// Ensemble des IDs des nœuds dépliés.
  final Set<String> _expandedIds = {};

  /// Requête de recherche courante.
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Vérifie si un nœud (ou un de ses descendants) correspond à la recherche.
  bool _matchesSearch(WidgetNode node) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    return node.type.toLowerCase().contains(query) ||
        node.id.toLowerCase().contains(query) ||
        _hasMatchingDescendant(node, query);
  }

  /// Vérifie récursivement si un descendant correspond à la recherche.
  bool _hasMatchingDescendant(WidgetNode node, String query) {
    if (node.child != null) {
      if (_matchesSearch(node.child!)) return true;
    }
    if (node.children != null) {
      for (final child in node.children!) {
        if (_matchesSearch(child)) return true;
      }
    }
    return false;
  }

  /// Construit récursivement les tuiles de l'arbre.
  List<Widget> _buildNodes(WidgetNode node, int depth) {
    if (!_matchesSearch(node)) return [];

    final List<Widget> result = [];
    final hasChildren = node.children != null && node.children!.isNotEmpty;
    final hasChild = node.child != null;
    final isExpanded = _expandedIds.contains(node.id);

    final nodeTile = _buildNodeTile(node, depth, hasChildren || hasChild);

    if (hasChildren || hasChild) {
      result.add(
        ExpansionTile(
          key: PageStorageKey(node.id),
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedIds.add(node.id);
              } else {
                _expandedIds.remove(node.id);
              }
            });
          },
          leading: nodeTile.leading,
          title: nodeTile.title,
          subtitle: nodeTile.subtitle,
          trailing: nodeTile.trailing,
          children: [
            if (node.child != null)
              ..._buildNodes(node.child!, depth + 1),
            if (node.children != null)
              ...node.children!.expand((child) => _buildNodes(child, depth + 1)),
          ],
        ),
      );
    } else {
      result.add(nodeTile);
    }
    return result;
  }

  /// Construit une tuile individuelle pour un nœud.
  ListTile _buildNodeTile(WidgetNode node, int depth, bool hasExpand) {
    final isSelected = node.id == widget.selectedWidgetId;
    final iconData = _getIconForType(node.type);
    final indent = depth * 16.0;

    return ListTile(
      contentPadding: EdgeInsets.only(left: indent + 8, right: 8),
      dense: true,
      selected: isSelected,
      selectedTileColor: AppColors.accent.withOpacity(0.2),
      leading: Icon(
        iconData,
        size: 20,
        color: isSelected ? AppColors.accent : null,
      ),
      title: Text(
        node.type,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        'ID: ${node.id}',
        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _buildTrailingMenu(node),
      onTap: () {
        widget.onSelect(node.id);
      },
    );
  }

  /// Menu contextuel (popup menu) pour les actions sur un nœud.
  Widget _buildTrailingMenu(WidgetNode node) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      onSelected: (action) {
        switch (action) {
          case 'select':
            widget.onSelect(node.id);
            break;
          case 'duplicate':
            widget.onDuplicate(node.id);
            break;
          case 'delete':
            widget.onDelete(node.id);
            break;
          case 'move_up':
            widget.onMoveUp?.call(node.id);
            break;
          case 'move_down':
            widget.onMoveDown?.call(node.id);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'select',
          child: ListTile(
            leading: const Icon(Icons.check),
            title: const Text('Sélectionner'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'duplicate',
          child: ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Dupliquer'),
            dense: true,
          ),
        ),
        if (widget.onMoveUp != null)
          PopupMenuItem(
            value: 'move_up',
            child: ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('Monter'),
              dense: true,
            ),
          ),
        if (widget.onMoveDown != null)
          PopupMenuItem(
            value: 'move_down',
            child: ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: const Text('Descendre'),
              dense: true,
            ),
          ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
            dense: true,
          ),
        ),
      ],
      icon: const Icon(Icons.more_vert, size: 18),
    );
  }

  /// Icône représentative d'un type de widget.
  IconData _getIconForType(String type) {
    switch (type) {
      case 'Scaffold':
        return Icons.smartphone;
      case 'Container':
        return Icons.crop_square;
      case 'Text':
        return Icons.text_fields;
      case 'Row':
        return Icons.view_column;
      case 'Column':
        return Icons.view_agenda;
      case 'Button':
      case 'ElevatedButton':
      case 'TextButton':
      case 'OutlinedButton':
        return Icons.smart_button;
      case 'Image':
        return Icons.image_outlined;
      case 'Icon':
        return Icons.emoji_emotions_outlined;
      case 'TextField':
        return Icons.input;
      case 'Checkbox':
        return Icons.check_box_outlined;
      case 'Switch':
        return Icons.toggle_on_outlined;
      case 'Slider':
        return Icons.linear_scale;
      case 'ListView':
        return Icons.list;
      case 'GridView':
        return Icons.grid_view;
      case 'ListTile':
        return Icons.view_list;
      case 'AppBar':
        return Icons.vertical_align_top;
      case 'SizedBox':
        return Icons.crop_din;
      case 'Padding':
        return Icons.crop_free;
      case 'Center':
        return Icons.center_focus_strong;
      default:
        return Icons.widgets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barre de recherche.
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              hintText: AppStrings.searchWidgets,
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        const Divider(height: 1),
        // Liste des nœuds.
        Expanded(
          child: ListView(
            children: _buildNodes(widget.root, 0),
          ),
        ),
      ],
    );
  }
}