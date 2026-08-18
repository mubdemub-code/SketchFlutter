import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../models/variable.dart';
import '../providers/variable_store.dart';

/// Widget de gestion des variables globales.
///
/// Affiche la liste des variables définies dans le projet actif et permet :
///   - d'ajouter une nouvelle variable,
///   - de modifier une variable existante (nom, type, valeur initiale),
///   - de supprimer une variable.
///
/// Ce widget s'appuie sur le provider [variableStoreProvider] pour accéder
/// aux variables et aux valeurs courantes. Il peut être utilisé dans l'onglet
/// Logique ou comme panneau autonome.
class VariableManager extends ConsumerWidget {
  const VariableManager({super.key});

  /// Ouvre le dialogue d'ajout ou de modification d'une variable.
  /// Si [existing] est fourni, le dialogue est en mode modification.
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
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? AppStrings.blockAddVariable
                    : 'Modifier la variable',
              ),
              content: SingleChildScrollView(
                child: Column(
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
                      value: selectedType,
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
                ),
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

  /// Demande confirmation avant suppression.
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

  /// Retourne l'icône associée au type de variable.
  IconData _getTypeIcon(VariableType type) {
    switch (type) {
      case VariableType.int:
        return Icons.looks_one_outlined;
      case VariableType.double:
        return Icons.looks_two_outlined;
      case VariableType.bool:
        return Icons.toggle_on_outlined;
      case VariableType.string:
        return Icons.text_fields;
      case VariableType.list:
        return Icons.list;
      case VariableType.map:
        return Icons.map_outlined;
      case VariableType.object:
        return Icons.data_object;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variableState = ref.watch(variableStoreProvider);
    final variables = variableState.variables;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // En-tête avec titre et bouton d'ajout.
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
        // Liste des variables.
        Expanded(
          child: variables.isEmpty
              ? Center(
                  child: Text(
                    AppStrings.noVariables,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.builder(
                  itemCount: variables.length,
                  itemBuilder: (context, index) {
                    final variable = variables[index];
                    final value = variableState.currentValues[variable.id];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: Icon(
                          _getTypeIcon(variable.type),
                          color: AppColors.accent,
                        ),
                        title: Text(variable.name),
                        subtitle: Text(
                          '${variable.type.displayName} - Valeur: $value',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) {
                            switch (action) {
                              case 'edit':
                                _showVariableDialog(context, ref,
                                    existing: variable);
                                break;
                              case 'delete':
                                _deleteVariable(context, ref, variable);
                                break;
                            }
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
                                leading: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                title: const Text(
                                  'Supprimer',
                                  style: TextStyle(color: Colors.red),
                                ),
                                dense: true,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          _showVariableDialog(context, ref, existing: variable);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}