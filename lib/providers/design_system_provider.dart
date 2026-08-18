import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/design_system.dart';
import '../models/project_model.dart';
import 'project_provider.dart';

/// État du design system courant.
class DesignSystemState {
  /// Design system actuel.
  final DesignSystem designSystem;

  const DesignSystemState(this.designSystem);

  DesignSystemState copyWith({DesignSystem? designSystem}) {
    return DesignSystemState(designSystem ?? this.designSystem);
  }
}

/// Notifier pour la gestion du design system du projet actif.
///
/// Ce notifier observe le projet actif et initialise son état avec le design
/// system du projet. Les méthodes de modification mettent à jour à la fois
/// le projet stocké (via [activeProjectProvider]) et l'état local.
class DesignSystemNotifier extends Notifier<DesignSystemState> {
  @override
  DesignSystemState build() {
    final project = ref.watch(activeProjectProvider);
    final designSystem = project?.designSystem ?? DesignSystem.defaults();
    return DesignSystemState(designSystem);
  }

  /// Récupère le design system actuel.
  DesignSystem get designSystem => state.designSystem;

  /// Met à jour le design system complet.
  void setDesignSystem(DesignSystem newDesignSystem) {
    final project = ref.read(activeProjectProvider);
    if (project != null) {
      final updatedProject = project.copyWith(designSystem: newDesignSystem);
      ref.read(activeProjectProvider.notifier).state = updatedProject;
    }
    state = state.copyWith(designSystem: newDesignSystem);
  }

  /// Ajoute ou remplace une couleur globale.
  void setColor(String name, String hexValue) {
    final current = designSystem;
    final newColors = Map<String, String>.from(current.colors);
    newColors[name] = hexValue;
    final newDesignSystem = current.copyWith(colors: newColors);
    setDesignSystem(newDesignSystem);
  }

  /// Supprime une couleur globale.
  void removeColor(String name) {
    final current = designSystem;
    final newColors = Map<String, String>.from(current.colors)..remove(name);
    final newDesignSystem = current.copyWith(colors: newColors);
    setDesignSystem(newDesignSystem);
  }

  /// Ajoute ou remplace un style de texte global.
  void setTextStyle(String name, Map<String, dynamic> style) {
    final current = designSystem;
    final newStyles = Map<String, Map<String, dynamic>>.from(current.textStyles);
    newStyles[name] = style;
    final newDesignSystem = current.copyWith(textStyles: newStyles);
    setDesignSystem(newDesignSystem);
  }

  /// Supprime un style de texte global.
  void removeTextStyle(String name) {
    final current = designSystem;
    final newStyles = Map<String, Map<String, dynamic>>.from(current.textStyles)
      ..remove(name);
    final newDesignSystem = current.copyWith(textStyles: newStyles);
    setDesignSystem(newDesignSystem);
  }

  /// Ajoute ou remplace un espacement global.
  void setSpacing(String name, double value) {
    final current = designSystem;
    final newSpacing = Map<String, double>.from(current.spacing);
    newSpacing[name] = value;
    final newDesignSystem = current.copyWith(spacing: newSpacing);
    setDesignSystem(newDesignSystem);
  }

  /// Supprime un espacement global.
  void removeSpacing(String name) {
    final current = designSystem;
    final newSpacing = Map<String, double>.from(current.spacing)..remove(name);
    final newDesignSystem = current.copyWith(spacing: newSpacing);
    setDesignSystem(newDesignSystem);
  }

  /// Résout une référence de design system (`@colors.xxx`, etc.).
  /// Retourne la valeur correspondante ou `null` si introuvable.
  dynamic resolveReference(String reference) {
    return designSystem.resolveReference(reference);
  }

  /// Récupère une couleur par nom, ou null.
  String? getColor(String name) => designSystem.getColor(name);

  /// Récupère un style de texte par nom, ou null.
  Map<String, dynamic>? getTextStyle(String name) =>
      designSystem.getTextStyle(name);

  /// Récupère un espacement par nom, ou null.
  double? getSpacing(String name) => designSystem.getSpacing(name);
}

/// Provider du design system.
final designSystemProvider =
    NotifierProvider<DesignSystemNotifier, DesignSystemState>(
  DesignSystemNotifier.new,
);