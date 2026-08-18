import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../models/logic_block.dart';
import '../models/page_model.dart';
import '../models/project_model.dart';
import '../models/variable.dart';
import '../models/widget_node.dart';
import '../providers/project_provider.dart';
import '../providers/variable_store.dart';

/// Onglet Logique de l'éditeur.
///
/// Cet onglet permet de :
///   - gérer les variables globales (ajout, modification, suppression) ;
///   - visualiser les widgets interactifs et leurs événements ;
///   - ajouter des blocs logiques simples (SnackBar, Navigation, Définition de variable)
///     aux événements des widgets.
///
/// L'édition des blocs se fait via des boîtes de dialogue dédiées.
/// Les variables sont gérées par [variableStoreProvider], tandis que les
/// événements et blocs sont stockés dans le projet actif (liaisons logiques).
class LogicTab extends ConsumerWidget {
  final ProjectModel project;

  const LogicTab({super.key, required this.project});

  // ---------------------------------------------------------------------------
  // Gestion des variables
  // ---------------------------------------------------------------------------

  /// Affiche le dialogue d'ajout ou de modification d'une variable.
  Future<void> _showVariableDialog(
    BuildContext context,
    WidgetRef ref, {
    Variable? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final valueController =
        TextEditingController(text: existing?.initialValue?.toString() ?? '');
    VariableType selectedType = existing?.type ?? VariableType.string;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(existing == null ? 'Ajouter une variable' : 'Modifier la variable'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: AppStrings.blockVariableName,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<VariableType>(
                    value: selectedType, // CORRECTION : 'value' au lieu de 'initialValue'
                    decoration: InputDecoration(
                      labelText: AppStrings.blockVariableType,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: VariableType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (newType) {
                      if (newType != null) {
                        setState(() {
                          selectedType = newType;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valueController,
                    decoration: InputDecoration(
                      labelText: AppStrings.blockVariableInitialValue,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: selectedType == VariableType.int ||
                            selectedType == VariableType.double
                        ? TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.of(dialogContext).pop({
                  'name': nameController.text.trim(),
                  'type': selectedType,
                  'value': valueController.text.trim(),
                });
              },
              child: const Text(AppStrings.ok),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final name = result['name'] as String;
      final type = result['type'] as VariableType;
      final valueStr = result['value'] as String;
      dynamic initialValue = valueStr.isEmpty ? null : valueStr;

      // Conversion de la valeur selon le type.
      try {
        switch (type) {
          case VariableType.int:
            initialValue = int.tryParse(valueStr);
            break;
          case VariableType.double:
            initialValue = double.tryParse(valueStr);
            break;
          case VariableType.bool:
            initialValue = valueStr.toLowerCase() == 'true';
            break;
          case VariableType.string:
            initialValue = valueStr;
            break;
          case VariableType.list:
          case VariableType.map:
          case VariableType.object:
            initialValue = valueStr; // conservé en texte pour simplification
            break;
        }
      } catch (_) {}

      final variableStore = ref.read(variableStoreProvider.notifier);
      if (existing == null) {
        final newVar = Variable.create(
          name: name,
          type: type,
          initialValue: initialValue,
        );
        variableStore.addVariable(newVar);
      } else {
        variableStore.updateVariable(
          existing.id,
          name: name,
          type: type,
          initialValue: initialValue,
        );
      }
    }
  }

  /// Supprime une variable après confirmation.
  Future<void> _deleteVariable(
    BuildContext context,
    WidgetRef ref,
    Variable variable,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la variable'),
        content: Text('Supprimer "${variable.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.deleteProject),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(variableStoreProvider.notifier).removeVariable(variable.id);
    }
  }

  // ---------------------------------------------------------------------------
  // Gestion des événements et blocs logiques
  // ---------------------------------------------------------------------------

  /// Récupère la liste des widgets interactifs d'une page donnée.
  /// Un widget est considéré interactif s'il possède au moins un événement
  /// dans les liaisons logiques, ou si son type est un widget interactif connu.
  List<WidgetNode> _getInteractiveWidgets(PageModel page) {
    final root = page.rootWidget;
    if (root == null) return [];
    final allNodes = root.getAllNodes();
    final interactiveTypes = {
      'Button',
      'ElevatedButton',
      'TextButton',
      'OutlinedButton',
      'TextField',
      'Checkbox',
      'Switch',
      'Slider',
      'ListTile',
    };
    return allNodes.where((node) => interactiveTypes.contains(node.type)).toList();
  }

  /// Obtient les événements associés à un widget (depuis les liaisons logiques).
  Map<String, List<Map<String, dynamic>>> _getEventsForWidget(
    PageModel page,
    String widgetId,
  ) {
    final bindings = page.logicBindings;
    if (bindings == null) return {};
    return bindings[widgetId] ?? {};
  }

  /// Affiche le dialogue pour ajouter un bloc logique à un événement.
  Future<void> _addBlockToEvent(
    BuildContext context,
    WidgetRef ref,
    PageModel page,
    String widgetId,
    String eventName,
  ) async {
    // Types de blocs disponibles.
    final blockTypes = [
      LogicBlockTypes.showSnackbar,
      LogicBlockTypes.navigateTo,
      LogicBlockTypes.setVariable,
    ];
    String? selectedType;

    final result = await showDialog<LogicBlock>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ajouter un bloc'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type de bloc',
                  border: OutlineInputBorder(),
                ),
                items: blockTypes
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  selectedType = value;
                },
              ),
              // Les paramètres spécifiques sont demandés après la sélection.
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedType == null) return;
                // Selon le type, on demande des paramètres supplémentaires.
                // On passe context pour éviter l'erreur.
                final block = await _createBlockFromTypeAsync(selectedType!, context);
                if (block != null) {
                  Navigator.of(dialogContext).pop(block);
                }
              },
              child: const Text(AppStrings.ok),
            ),
          ],
        );
      },
    );

    if (result != null) {
      // Ajouter le bloc à l'événement du widget dans le projet.
      final updatedPage = _addBlockToPageEvent(
        page,
        widgetId,
        eventName,
        result,
      );
      final updatedPages = project.pages
          .map((p) => p.id == updatedPage.id ? updatedPage : p)
          .toList();
      final updatedProject = project.copyWith(pages: updatedPages);
      ref.read(activeProjectProvider.notifier).state = updatedProject;
    }
  }

  /// Crée un bloc logique à partir du type sélectionné de manière asynchrone.
  Future<LogicBlock?> _createBlockFromTypeAsync(String type, BuildContext context) async {
    switch (type) {
      case LogicBlockTypes.showSnackbar:
        final message = await _promptForStringAsync(context, 'Message du SnackBar');
        if (message != null && message.isNotEmpty) {
          return LogicBlock.create(
            type: type,
            parameters: {'message': message},
          );
        }
        break;
      case LogicBlockTypes.navigateTo:
        final pageId = await _promptForStringAsync(context, 'ID de la page de destination');
        if (pageId != null && pageId.isNotEmpty) {
          return LogicBlock.create(
            type: type,
            parameters: {'page_id': pageId},
          );
        }
        break;
      case LogicBlockTypes.setVariable:
        final variableId = await _promptForStringAsync(context, 'ID de la variable');
        final value = await _promptForStringAsync(context, 'Valeur à définir');
        if (variableId != null && variableId.isNotEmpty && value != null && value.isNotEmpty) {
          return LogicBlock.create(
            type: type,
            parameters: {'variable_id': variableId, 'value': value},
          );
        }
        break;
    }
    return null;
  }

  /// Helper pour demander une chaîne via une boîte de dialogue asynchrone.
  Future<String?> _promptForStringAsync(BuildContext context, String label) async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(label),
          content: TextField(
            controller: controller,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Ajoute un bloc à un événement spécifique d'un widget dans une page.
  PageModel _addBlockToPageEvent(
    PageModel page,
    String widgetId,
    String eventName,
    LogicBlock block,
  ) {
    final currentBindings = page.logicBindings ?? {};
    final widgetEvents = Map<String, List<Map<String, dynamic>>>.from(
      currentBindings[widgetId] ?? {},
    );
    final blocks = List<Map<String, dynamic>>.from(widgetEvents[eventName] ?? []);
    blocks.add(block.toJson());
    widgetEvents[eventName] = blocks;
    final newBindings = Map<String, Map<String, List<Map<String, dynamic>>>>.from(
      currentBindings,
    );
    newBindings[widgetId] = widgetEvents;
    return page.copyWith(logicBindings: newBindings);
  }

  /// Affiche la liste des blocs d'un événement.
  void _showEventBlocks(
    BuildContext context,
    WidgetRef ref,
    PageModel page,
    String widgetId,
    String eventName,
  ) {
    final events = _getEventsForWidget(page, widgetId);
    final blocks = events[eventName] ?? [];
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Blocs de $eventName'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: blocks.length,
              itemBuilder: (context, index) {
                final block = blocks[index];
                return ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(block['type']?.toString() ?? 'Bloc'),
                  subtitle: Text(block.toString()),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Construction de l'interface
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variableState = ref.watch(variableStoreProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Variables
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.variableManager,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              FilledButton.icon(
                onPressed: () => _showVariableDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text(AppStrings.blockAddVariable),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Liste des variables (compacte, sous forme de chips ou de liste).
        if (variableState.variables.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              itemCount: variableState.variables.length,
              itemBuilder: (context, index) {
                final variable = variableState.variables[index];
                return Card(
                  margin: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _showVariableDialog(context, ref, existing: variable),
                    onLongPress: () => _deleteVariable(context, ref, variable), // Ajout utile : pouvoir supprimer la variable
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            variable.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${variable.type.displayName} : ${variableState.currentValues[variable.id]}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        const Divider(height: 1),

        // Section Événements des widgets interactifs
        Expanded(
          child: _buildEventsSection(context, ref),
        ),
      ],
    );
  }

  /// Construit la section listant les widgets interactifs et leurs événements.
  Widget _buildEventsSection(BuildContext context, WidgetRef ref) {
    final pages = project.pages;
    if (pages.isEmpty) {
      return const Center(child: Text('Aucune page'));
    }

    // On liste les widgets interactifs de toutes les pages.
    final List<Widget> eventWidgets = [];
    for (final page in pages) {
      final interactiveWidgets = _getInteractiveWidgets(page);
      for (final widget in interactiveWidgets) {
        final events = _getEventsForWidget(page, widget.id);
        // Si le widget a déjà des événements enregistrés, on les liste,
        // sinon on propose d'ajouter un événement.
        if (events.isNotEmpty) {
          events.forEach((eventName, blocks) {
            eventWidgets.add(
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    _getIconForWidgetType(widget.type),
                    color: AppColors.accent,
                  ),
                  title: Text('${widget.type} (${widget.id})'),
                  subtitle: Text('$eventName (${blocks.length} blocs)'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      _showEventBlocks(context, ref, page, widget.id, eventName);
                    },
                  ),
                  onLongPress: () {
                    // Ajouter un bloc à cet événement.
                    _addBlockToEvent(context, ref, page, widget.id, eventName);
                  },
                ),
              ),
            );
          });
        } else {
          // Widget interactif sans événement : proposer les événements possibles.
          final possibleEvents = _getPossibleEventsForType(widget.type);
          for (final eventName in possibleEvents) {
            eventWidgets.add(
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    _getIconForWidgetType(widget.type),
                    color: Colors.grey,
                  ),
                  title: Text('${widget.type} (${widget.id})'),
                  subtitle: Text('Ajouter un bloc à $eventName'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      _addBlockToEvent(context, ref, page, widget.id, eventName);
                    },
                  ),
                ),
              ),
            );
          }
        }
      }
    }

    if (eventWidgets.isEmpty) {
      return const Center(
        child: Text('Aucun widget interactif. Ajoutez des boutons, champs, etc.'),
      );
    }

    return ListView(
      children: eventWidgets,
    );
  }

  /// Retourne les événements possibles pour un type de widget donné.
  List<String> _getPossibleEventsForType(String type) {
    switch (type) {
      case 'Button':
      case 'ElevatedButton':
      case 'TextButton':
      case 'OutlinedButton':
        return ['onPressed'];
      case 'TextField':
        return ['onChanged', 'onSubmitted'];
      case 'Checkbox':
      case 'Switch':
        return ['onChanged'];
      case 'Slider':
        return ['onChanged'];
      case 'ListTile':
        return ['onTap'];
      default:
        return ['onTap'];
    }
  }

  /// Icône représentative d'un type de widget.
  IconData _getIconForWidgetType(String type) {
    switch (type) {
      case 'Button':
      case 'ElevatedButton':
      case 'TextButton':
      case 'OutlinedButton':
        return Icons.smart_button;
      case 'TextField':
        return Icons.input;
      case 'Checkbox':
        return Icons.check_box;
      case 'Switch':
        return Icons.toggle_on;
      case 'Slider':
        return Icons.linear_scale;
      case 'ListTile':
        return Icons.list;
      default:
        return Icons.widgets;
    }
  }
}
