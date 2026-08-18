import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/design_system.dart';
import 'design_system_provider.dart';
import 'variable_store.dart';

/// Contexte du moteur de rendu.
///
/// Regroupe les données nécessaires pour interpréter le JSON des widgets
/// et produire des widgets Flutter. Ce contexte est fourni par le provider
/// et se met à jour automatiquement lorsque le design system ou les variables
/// changent.
class RenderEngineContext {
  /// Design system courant (couleurs, styles de texte, espacements).
  final DesignSystem designSystem;

  /// Valeurs courantes des variables (clé = variableId, valeur).
  final Map<String, dynamic> variables;

  const RenderEngineContext({
    required this.designSystem,
    required this.variables,
  });

  /// Récupère la valeur d'une variable par son identifiant.
  /// Si la variable n'existe pas, retourne `null`.
  dynamic getVariableValue(String variableId) {
    return variables[variableId];
  }

  /// Résout une référence éventuelle `@variables.xxx`.
  /// Si la chaîne commence par `@variables.`, retourne la valeur correspondante,
  /// sinon retourne la chaîne inchangée.
  dynamic resolveVariableReference(String value) {
    if (value.startsWith('@variables.')) {
      final varId = value.substring('@variables.'.length);
      return getVariableValue(varId);
    }
    return value;
  }
}

/// Provider du contexte du moteur de rendu.
///
/// Ce provider observe :
///   - le design system (via [designSystemProvider]),
///   - les valeurs courantes des variables (via [variableStoreProvider]).
///
/// Il fournit un [RenderEngineContext] immuable qui sera utilisé par le
/// parseur JSON → Widget pour résoudre les références et construire l'interface.
final renderEngineProvider = Provider<RenderEngineContext>((ref) {
  final designSystem = ref.watch(designSystemProvider).designSystem;
  final variableState = ref.watch(variableStoreProvider);

  return RenderEngineContext(
    designSystem: designSystem,
    variables: variableState.currentValues,
  );
});