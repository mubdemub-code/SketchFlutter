import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project_model.dart';
import '../models/variable.dart';
import 'project_provider.dart';

/// État du magasin de variables.
/// Contient la liste des variables définies dans le projet et un dictionnaire
/// des valeurs courantes (utilisées pendant l'exécution en mode aperçu).
class VariableStoreState {
  /// Liste des variables (métadonnées).
  final List<Variable> variables;

  /// Valeurs courantes de chaque variable (clé = variableId).
  final Map<String, dynamic> currentValues;

  const VariableStoreState({
    this.variables = const [],
    this.currentValues = const {},
  });

  VariableStoreState copyWith({
    List<Variable>? variables,
    Map<String, dynamic>? currentValues,
  }) {
    return VariableStoreState(
      variables: variables ?? this.variables,
      currentValues: currentValues ?? this.currentValues,
    );
  }
}

/// Notifier pour la gestion des variables globales du projet actif.
///
/// Ce notifier observe le projet actif et initialise son état avec les variables
/// du projet. Les méthodes de modification mettent à jour à la fois l'état local
/// (pour la réactivité) et le projet stocké (via [activeProjectProvider]).
class VariableStoreNotifier extends Notifier<VariableStoreState> {
  @override
  VariableStoreState build() {
    final project = ref.watch(activeProjectProvider);
    final variables = project?.variables ?? const <Variable>[];
    // Initialiser les valeurs courantes avec les valeurs initiales.
    final Map<String, dynamic> initialValues = {};
    for (final variable in variables) {
      initialValues[variable.id] = variable.initialValue;
    }
    return VariableStoreState(
      variables: variables,
      currentValues: initialValues,
    );
  }

  /// Récupère la valeur courante d'une variable par son identifiant.
  dynamic getValue(String variableId) {
    return state.currentValues[variableId];
  }

  /// Définit la valeur courante d'une variable (sans modifier le projet).
  void setValue(String variableId, dynamic value) {
    final newValues = Map<String, dynamic>.from(state.currentValues);
    newValues[variableId] = value;
    state = state.copyWith(currentValues: newValues);
  }

  /// Ajoute une nouvelle variable au projet actif.
  void addVariable(Variable variable) {
    final project = ref.read(activeProjectProvider);
    if (project == null) return;

    // Mettre à jour le projet.
    final updatedProject = project.addVariable(variable);
    ref.read(activeProjectProvider.notifier).state = updatedProject;

    // Mettre à jour l'état local.
    final newVariables = List<Variable>.from(state.variables)..add(variable);
    final newValues = Map<String, dynamic>.from(state.currentValues);
    newValues[variable.id] = variable.initialValue;
    state = state.copyWith(
      variables: newVariables,
      currentValues: newValues,
    );
  }

  /// Supprime une variable par son identifiant.
  void removeVariable(String variableId) {
    final project = ref.read(activeProjectProvider);
    if (project == null) return;

    final updatedProject = project.removeVariable(variableId);
    ref.read(activeProjectProvider.notifier).state = updatedProject;

    final newVariables = state.variables.where((v) => v.id != variableId).toList();
    final newValues = Map<String, dynamic>.from(state.currentValues)..remove(variableId);
    state = state.copyWith(
      variables: newVariables,
      currentValues: newValues,
    );
  }

  /// Met à jour les propriétés d'une variable existante.
  ///
  /// [variableId] : identifiant de la variable.
  /// [name], [type], [initialValue], [persistent] : nouveaux champs (null = inchangé).
  /// Si [initialValue] est fourni et que la valeur courante n'a pas été modifiée
  /// manuellement (c'est-à-dire qu'elle est égale à l'ancienne valeur initiale),
  /// elle est remplacée par la nouvelle valeur initiale.
  void updateVariable(
    String variableId, {
    String? name,
    VariableType? type,
    dynamic initialValue,
    bool? persistent,
  }) {
    final project = ref.read(activeProjectProvider);
    if (project == null) return;

    final existing = project.getVariableById(variableId);
    if (existing == null) return;

    final updatedVariable = existing.copyWith(
      name: name,
      type: type,
      initialValue: initialValue,
      persistent: persistent,
    );

    // Remplacer la variable dans le projet.
    final updatedVariables = project.variables
        .map((v) => v.id == variableId ? updatedVariable : v)
        .toList();
    final updatedProject = project.copyWith(variables: updatedVariables);
    ref.read(activeProjectProvider.notifier).state = updatedProject;

    // Mettre à jour l'état local.
    final newVariables = state.variables
        .map((v) => v.id == variableId ? updatedVariable : v)
        .toList();
    final currentValues = Map<String, dynamic>.from(state.currentValues);

    // Si la valeur courante était égale à l'ancienne valeur initiale,
    // on la met à jour avec la nouvelle valeur initiale.
    if (initialValue != null) {
      final oldInitial = existing.initialValue;
      if (currentValues[variableId] == oldInitial) {
        currentValues[variableId] = initialValue;
      }
    }

    state = state.copyWith(
      variables: newVariables,
      currentValues: currentValues,
    );
  }

  /// Réinitialise la valeur courante d'une variable à sa valeur initiale.
  void resetValue(String variableId) {
    final project = ref.read(activeProjectProvider);
    if (project == null) return;

    final variable = project.getVariableById(variableId);
    if (variable == null) return;

    final newValues = Map<String, dynamic>.from(state.currentValues);
    newValues[variableId] = variable.initialValue;
    state = state.copyWith(currentValues: newValues);
  }

  /// Récupère la variable par son identifiant, ou null.
  Variable? getVariableById(String variableId) {
    for (final v in state.variables) {
      if (v.id == variableId) return v;
    }
    return null;
  }

  /// Récupère la liste des variables (copie immuable).
  List<Variable> get variables => List.unmodifiable(state.variables);
}

/// Provider du magasin de variables.
final variableStoreProvider =
    NotifierProvider<VariableStoreNotifier, VariableStoreState>(
  VariableStoreNotifier.new,
);