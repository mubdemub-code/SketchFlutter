import '../core/errors/validation_error.dart';
import '../core/utils/json_utils.dart';

/// Code Dart personnalisé injecté dans le projet généré.
///
/// Ce modèle stocke les fragments de code écrits par l'utilisateur avancé,
/// qui seront intégrés tels quels dans les fichiers générés lors de la compilation.
///
/// Les champs disponibles sont :
///   - [dartImports] : instructions `import` supplémentaires (Dart et packages).
///   - [globalFunctions] : fonctions globales ajoutées en dehors des classes.
///   - [additionalClasses] : classes Dart personnalisées.
///   - [initCode] : code exécuté au démarrage (dans `main()`).
///   - [additionalFiles] : fichiers Dart supplémentaires (chemin relatif -> contenu).
///
/// Tous les champs sont optionnels. La classe est immuable ; utilisez [copyWith]
/// pour créer des copies modifiées.
class CustomCode {
  /// Imports Dart supplémentaires (ex: `import 'dart:math';`).
  final String? dartImports;

  /// Fonctions globales (ex: `String formatDate(DateTime d) { ... }`).
  final String? globalFunctions;

  /// Classes supplémentaires (ex: `class MyModel { ... }`).
  final String? additionalClasses;

  /// Code d'initialisation (ex: appel de `WidgetsFlutterBinding.ensureInitialized();`).
  final String? initCode;

  /// Fichiers Dart additionnels, mappés par chemin relatif (ex: `lib/utils/helper.dart` → code).
  final Map<String, String>? additionalFiles;

  /// Constructeur principal.
  const CustomCode({
    this.dartImports,
    this.globalFunctions,
    this.additionalClasses,
    this.initCode,
    this.additionalFiles,
  });

  /// Crée une instance à partir d'une map JSON.
  ///
  /// [json] : la map contenant le code personnalisé.
  /// Les champs reconnus sont : `dart_imports`, `global_functions`,
  /// `additional_classes`, `init_code`, `additional_files`.
  /// Les champs absents sont ignorés (restent null).
  ///
  /// Lève une [ValidationError] si un champ a un type incorrect.
  factory CustomCode.fromJson(Map<String, dynamic> json) {
    // Imports
    String? dartImports;
    if (json.containsKey('dart_imports')) {
      final dynamic value = json['dart_imports'];
      if (value == null) {
        dartImports = null;
      } else if (value is String) {
        dartImports = value;
      } else {
        throw ValidationError.invalidType(
          'dart_imports',
          'String',
          '${value.runtimeType}',
          path: 'custom_code',
        );
      }
    }

    // Fonctions globales
    String? globalFunctions;
    if (json.containsKey('global_functions')) {
      final dynamic value = json['global_functions'];
      if (value == null) {
        globalFunctions = null;
      } else if (value is String) {
        globalFunctions = value;
      } else {
        throw ValidationError.invalidType(
          'global_functions',
          'String',
          '${value.runtimeType}',
          path: 'custom_code',
        );
      }
    }

    // Classes supplémentaires
    String? additionalClasses;
    if (json.containsKey('additional_classes')) {
      final dynamic value = json['additional_classes'];
      if (value == null) {
        additionalClasses = null;
      } else if (value is String) {
        additionalClasses = value;
      } else {
        throw ValidationError.invalidType(
          'additional_classes',
          'String',
          '${value.runtimeType}',
          path: 'custom_code',
        );
      }
    }

    // Code d'initialisation
    String? initCode;
    if (json.containsKey('init_code')) {
      final dynamic value = json['init_code'];
      if (value == null) {
        initCode = null;
      } else if (value is String) {
        initCode = value;
      } else {
        throw ValidationError.invalidType(
          'init_code',
          'String',
          '${value.runtimeType}',
          path: 'custom_code',
        );
      }
    }

    // Fichiers supplémentaires
    Map<String, String>? additionalFiles;
    if (json.containsKey('additional_files')) {
      final dynamic filesData = json['additional_files'];
      if (filesData == null) {
        additionalFiles = null;
      } else if (filesData is Map<String, dynamic>) {
        additionalFiles = {};
        filesData.forEach((key, value) {
          if (value is String) {
            additionalFiles![key] = value;
          } else {
            throw ValidationError.invalidType(
              'additional_files.$key',
              'String',
              '${value.runtimeType}',
              path: 'custom_code.additional_files',
            );
          }
        });
      } else {
        throw ValidationError.invalidType(
          'additional_files',
          'Map<String, String>',
          '${filesData.runtimeType}',
          path: 'custom_code.additional_files',
        );
      }
    }

    return CustomCode(
      dartImports: dartImports,
      globalFunctions: globalFunctions,
      additionalClasses: additionalClasses,
      initCode: initCode,
      additionalFiles: additionalFiles,
    );
  }

  /// Convertit le code personnalisé en map JSON.
  Map<String, dynamic> toJson() {
    return {
      if (dartImports != null) 'dart_imports': dartImports,
      if (globalFunctions != null) 'global_functions': globalFunctions,
      if (additionalClasses != null) 'additional_classes': additionalClasses,
      if (initCode != null) 'init_code': initCode,
      if (additionalFiles != null && additionalFiles!.isNotEmpty)
        'additional_files': additionalFiles,
    };
  }

  /// Crée une copie en remplaçant certains champs.
  CustomCode copyWith({
    String? dartImports,
    String? globalFunctions,
    String? additionalClasses,
    String? initCode,
    Map<String, String>? additionalFiles,
  }) {
    return CustomCode(
      dartImports: dartImports ?? this.dartImports,
      globalFunctions: globalFunctions ?? this.globalFunctions,
      additionalClasses: additionalClasses ?? this.additionalClasses,
      initCode: initCode ?? this.initCode,
      additionalFiles: additionalFiles ?? this.additionalFiles,
    );
  }

  /// Retourne une copie profonde.
  CustomCode deepCopy() {
    return CustomCode(
      dartImports: dartImports,
      globalFunctions: globalFunctions,
      additionalClasses: additionalClasses,
      initCode: initCode,
      additionalFiles: additionalFiles != null
          ? Map<String, String>.from(additionalFiles!)
          : null,
    );
  }

  /// Vérifie si le code personnalisé est vide (aucun champ renseigné).
  bool get isEmpty {
    return (dartImports == null || dartImports!.trim().isEmpty) &&
        (globalFunctions == null || globalFunctions!.trim().isEmpty) &&
        (additionalClasses == null || additionalClasses!.trim().isEmpty) &&
        (initCode == null || initCode!.trim().isEmpty) &&
        (additionalFiles == null || additionalFiles!.isEmpty);
  }

  /// Vérifie si le code personnalisé contient du contenu non vide.
  bool get isNotEmpty => !isEmpty;

  /// Fusionne ce code avec un autre : les champs non nuls de [other] prennent le dessus.
  CustomCode merge(CustomCode other) {
    return CustomCode(
      dartImports: other.dartImports ?? dartImports,
      globalFunctions: other.globalFunctions ?? globalFunctions,
      additionalClasses: other.additionalClasses ?? additionalClasses,
      initCode: other.initCode ?? initCode,
      additionalFiles: additionalFiles != null || other.additionalFiles != null
          ? {
              ...?additionalFiles,
              ...?other.additionalFiles,
            }
          : null,
    );
  }

  @override
  String toString() =>
      'CustomCode(imports: ${dartImports != null ? 'yes' : 'no'}, functions: ${globalFunctions != null ? 'yes' : 'no'}, classes: ${additionalClasses != null ? 'yes' : 'no'}, files: ${additionalFiles?.length ?? 0})';
}