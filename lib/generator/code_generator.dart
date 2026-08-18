import '../models/project_model.dart';
import 'pubspec_generator.dart';
import 'project_to_dart.dart';

/// Interface de génération de code source (pour découplage avec les services).
abstract class IProjectCodeGenerator {
  Map<String, String> generate(ProjectModel project);
}

/// Générateur de code principal.
///
/// Transforme un [ProjectModel] en un ensemble de fichiers source Flutter
/// prêts à être compilés :
///   - `pubspec.yaml`
///   - `lib/main.dart`
///   - `lib/app_state.dart` (état global réactif)
///   - `lib/pages/<page>_page.dart` pour chaque page
///   - fichiers personnalisés éventuels (via `additionalFiles`)
///
/// Le code produit est autonome (ne dépend que du SDK Flutter) et gère
/// la réactivité des variables, les événements et la navigation.
class CodeGenerator implements IProjectCodeGenerator {
  @override
  Map<String, String> generate(ProjectModel project) {
    final files = <String, String>{};

    // 1. Générer pubspec.yaml
    files['pubspec.yaml'] = PubspecGenerator.generate(project);

    // 2. Générer l'état global (variables réactives)
    files['lib/app_state.dart'] = ProjectToDart.generateAppState(project);

    // 3. Générer le fichier main.dart
    files['lib/main.dart'] = ProjectToDart.generateMain(project);

    // 4. Générer un fichier par page
    for (final page in project.pages) {
      final pageFileName = _toSnakeCase(page.name);
      files['lib/pages/${pageFileName}_page.dart'] =
          ProjectToDart.generatePage(project, page);
    }

    // 5. Ajouter les fichiers Dart personnalisés (si présents)
    if (project.customCode.additionalFiles != null) {
      project.customCode.additionalFiles!.forEach((path, content) {
        files[path] = content;
      });
    }

    return files;
  }

  /// Convertit un nom en snake_case (minuscules, underscores).
  String _toSnakeCase(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}