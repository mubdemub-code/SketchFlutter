import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../models/logic_block.dart';
import '../models/variable.dart';

/// Éditeur de blocs logiques.
///
/// Ce widget affiche une liste de blocs logiques associés à un événement
/// (ex: onPressed, onTap). Il permet d'ajouter, modifier, supprimer et
/// réordonner (à venir) les blocs.
///
/// L'édition se fait via un dialogue dynamique qui génère les champs
/// nécessaires en fonction du type de bloc.
///
/// Exemple d'utilisation :
/// ```dart
/// LogicBlockEditor(
///   blocks: myBlocks, // List<LogicBlock>
///   availableVariables: myVariables, // List<Variable> pour les dropdowns
///   onChanged: (newBlocks) { ... },
/// )
/// ```
///
/// Le widget est autonome et ne dépend pas de Riverpod ; il gère son état
/// localement et remonte les changements via [onChanged].
class LogicBlockEditor extends StatefulWidget {
  /// Liste initiale des blocs.
  final List<LogicBlock> blocks;

  /// Liste des variables disponibles (pour les blocs set_variable).
  final List<Variable> availableVariables;

  /// Callback appelé lorsque la liste des blocs change.
  final ValueChanged<List<LogicBlock>> onChanged;

  /// Indique si l'éditeur est en lecture seule (par exemple pendant l'exécution).
  final bool readOnly;

  const LogicBlockEditor({
    super.key,
    required this.blocks,
    required this.availableVariables,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<LogicBlockEditor> createState() => _LogicBlockEditorState();
}

class _LogicBlockEditorState extends State<LogicBlockEditor> {
  late List<LogicBlock> _blocks;

  @override
  void initState() {
    super.initState();
    _blocks = List.from(widget.blocks);
  }

  @override
  void didUpdateWidget(LogicBlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blocks != widget.blocks) {
      _blocks = List.from(widget.blocks);
    }
  }

  void _emitChange() {
    widget.onChanged(List<LogicBlock>.from(_blocks));
  }

  /// Ouvre le dialogue pour ajouter un nouveau bloc.
  Future<void> _addBlock() async {
    final newBlock = await showDialog<LogicBlock>(
      context: context,
      builder: (dialogContext) => _BlockEditorDialog(
        variables: widget.availableVariables,
      ),
    );
    if (newBlock != null) {
      setState(() {
        _blocks.add(newBlock);
      });
      _emitChange();
    }
  }

  /// Ouvre le dialogue pour modifier un bloc existant.
  Future<void> _editBlock(int index) async {
    final updatedBlock = await showDialog<LogicBlock>(
      context: context,
      builder: (dialogContext) => _BlockEditorDialog(
        initialBlock: _blocks[index],
        variables: widget.availableVariables,
      ),
    );
    if (updatedBlock != null) {
      setState(() {
        _blocks[index] = updatedBlock;
      });
      _emitChange();
    }
  }

  /// Supprime un bloc à l'index donné.
  void _deleteBlock(int index) {
    setState(() {
      _blocks.removeAt(index);
    });
    _emitChange();
  }

  /// Déplace un bloc vers le haut (si possible).
  void _moveUp(int index) {
    if (index <= 0) return;
    setState(() {
      final block = _blocks.removeAt(index);
      _blocks.insert(index - 1, block);
    });
    _emitChange();
  }

  /// Déplace un bloc vers le bas (si possible).
  void _moveDown(int index) {
    if (index >= _blocks.length - 1) return;
    setState(() {
      final block = _blocks.removeAt(index);
      _blocks.insert(index + 1, block);
    });
    _emitChange();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // En-tête avec bouton d'ajout.
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.blocks,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!widget.readOnly)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: AppStrings.addBlock,
                  onPressed: _addBlock,
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Liste des blocs.
        Expanded(
          child: _blocks.isEmpty
              ? Center(
                  child: Text(
                    'Aucun bloc. Ajoutez un bloc pour définir une action.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ReorderableListView.builder(
                  itemCount: _blocks.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final block = _blocks.removeAt(oldIndex);
                      _blocks.insert(newIndex, block);
                    });
                    _emitChange();
                  },
                  itemBuilder: (context, index) {
                    final block = _blocks[index];
                    return _BlockTile(
                      key: ValueKey(block.id ?? index),
                      block: block,
                      index: index,
                      readOnly: widget.readOnly,
                      onEdit: () => _editBlock(index),
                      onDelete: () => _deleteBlock(index),
                      onMoveUp: () => _moveUp(index),
                      onMoveDown: () => _moveDown(index),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Tuile représentant un bloc dans la liste.
class _BlockTile extends StatelessWidget {
  final LogicBlock block;
  final int index;
  final bool readOnly;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _BlockTile({
    super.key,
    required this.block,
    required this.index,
    required this.readOnly,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surface : Colors.white;
    final textColor = isDark ? AppColors.textPrimary : Colors.black87;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          _getIconForType(block.type),
          color: AppColors.accent,
        ),
        title: Text(
          _getLabelForType(block.type),
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _getParametersSummary(block),
          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: readOnly
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    tooltip: 'Monter',
                    onPressed: onMoveUp,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    tooltip: 'Descendre',
                    onPressed: onMoveDown,
                  ),
                  PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'edit') onEdit();
                      if (action == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: const Icon(Icons.edit_outlined),
                          title: const Text('Modifier'),
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: const Icon(Icons.delete_outline, color: Colors.red),
                          title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                          dense: true,
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert, size: 18),
                  ),
                ],
              ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case LogicBlockTypes.showSnackbar:
        return Icons.chat_bubble_outline;
      case LogicBlockTypes.navigateTo:
        return Icons.navigation_outlined;
      case LogicBlockTypes.setVariable:
        return Icons.edit;
      case LogicBlockTypes.ifBlock:
        return Icons.call_split;
      case LogicBlockTypes.loopBlock:
        return Icons.loop;
      case LogicBlockTypes.callApi:
        return Icons.cloud_outlined;
      default:
        return Icons.code;
    }
  }

  String _getLabelForType(String type) {
    switch (type) {
      case LogicBlockTypes.showSnackbar:
        return 'Afficher un message';
      case LogicBlockTypes.navigateTo:
        return 'Naviguer vers une page';
      case LogicBlockTypes.setVariable:
        return 'Définir une variable';
      case LogicBlockTypes.ifBlock:
        return 'Condition (Si)';
      case LogicBlockTypes.loopBlock:
        return 'Boucle';
      case LogicBlockTypes.callApi:
        return 'Appeler une API';
      default:
        return type;
    }
  }

  String _getParametersSummary(LogicBlock block) {
    final params = block.parameters;
    if (params == null || params.isEmpty) return 'Aucun paramètre';
    switch (block.type) {
      case LogicBlockTypes.showSnackbar:
        return 'Message: ${params['message'] ?? ''}';
      case LogicBlockTypes.navigateTo:
        return 'Page: ${params['page_id'] ?? ''}';
      case LogicBlockTypes.setVariable:
        return 'Variable: ${params['variable_id'] ?? ''} = ${params['value'] ?? ''}';
      default:
        return params.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    }
  }
}

/// Dialogue d'édition d'un bloc (ajout ou modification).
///
/// Génère dynamiquement les champs en fonction du type de bloc sélectionné.
class _BlockEditorDialog extends StatefulWidget {
  final LogicBlock? initialBlock;
  final List<Variable> variables;

  const _BlockEditorDialog({
    this.initialBlock,
    required this.variables,
  });

  @override
  State<_BlockEditorDialog> createState() => _BlockEditorDialogState();
}

class _BlockEditorDialogState extends State<_BlockEditorDialog> {
  late String _selectedType;
  late TextEditingController _messageController;
  late TextEditingController _pageIdController;
  late String? _selectedVariableId;
  late TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialBlock;
    _selectedType = initial?.type ?? LogicBlockTypes.showSnackbar;
    _messageController =
        TextEditingController(text: initial?.getStringParameter('message') ?? '');
    _pageIdController =
        TextEditingController(text: initial?.getStringParameter('page_id') ?? '');
    _selectedVariableId = initial?.getStringParameter('variable_id');
    _valueController =
        TextEditingController(text: initial?.getParameter('value')?.toString() ?? '');
  }

  @override
  void dispose() {
    _messageController.dispose();
    _pageIdController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  /// Construit un bloc à partir des champs saisis.
  LogicBlock _buildBlock() {
    final params = <String, dynamic>{};
    switch (_selectedType) {
      case LogicBlockTypes.showSnackbar:
        params['message'] = _messageController.text.trim();
        break;
      case LogicBlockTypes.navigateTo:
        params['page_id'] = _pageIdController.text.trim();
        break;
      case LogicBlockTypes.setVariable:
        params['variable_id'] = _selectedVariableId ?? '';
        params['value'] = _valueController.text.trim();
        break;
      // Pour les types plus complexes, on pourrait ajouter d'autres champs.
    }
    return LogicBlock.create(
      type: _selectedType,
      parameters: params,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white24 : Colors.black26;

    return AlertDialog(
      title: Text(widget.initialBlock == null ? 'Ajouter un bloc' : 'Modifier le bloc'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: InputDecoration(
                labelText: 'Type de bloc',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                LogicBlockTypes.showSnackbar,
                LogicBlockTypes.navigateTo,
                LogicBlockTypes.setVariable,
              ].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            // Champs spécifiques selon le type.
            if (_selectedType == LogicBlockTypes.showSnackbar) ...[
              TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else if (_selectedType == LogicBlockTypes.navigateTo) ...[
              TextField(
                controller: _pageIdController,
                decoration: InputDecoration(
                  labelText: 'ID de la page de destination',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else if (_selectedType == LogicBlockTypes.setVariable) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedVariableId,
                decoration: InputDecoration(
                  labelText: 'Variable',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: widget.variables
                    .map((v) => DropdownMenuItem(value: v.id, child: Text(v.name)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedVariableId = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _valueController,
                decoration: InputDecoration(
                  labelText: 'Valeur',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: () {
            final block = _buildBlock();
            Navigator.of(context).pop(block);
          },
          child: const Text(AppStrings.ok),
        ),
      ],
    );
  }
}