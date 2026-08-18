/// Types d'erreurs possibles lors de l'importation d'un projet.
enum ProjectImportErrorType {
  /// Le fichier sélectionné n'est pas un fichier .mub valide.
  invalidFile,

  /// Le contenu du fichier n'est pas un JSON valide.
  invalidJson,

  /// La version du schéma n'est pas supportée.
  unsupportedVersion,

  /// Le fichier est corrompu ou incomplet.
  corruptData,

  /// Erreur inconnue lors de l'importation.
  unknown,
}

/// Exception levée lors d'une erreur d'importation de projet .mub.
///
/// Cette classe contient des informations détaillées sur la nature de l'erreur,
/// facilitant le débogage et l'affichage de messages à l'utilisateur.
class ProjectImportError implements Exception {
  /// Message décrivant l'erreur.
  final String message;

  /// Type d'erreur spécifique.
  final ProjectImportErrorType type;

  /// Cause originale (exception sous-jacente), si disponible.
  final Object? cause;

  /// Chemin du fichier concerné, si applicable.
  final String? filePath;

  /// Constructeur.
  ///
  /// [message] : description lisible de l'erreur.
  /// [type] : catégorie d'erreur (par défaut [ProjectImportErrorType.unknown]).
  /// [cause] : exception sous-jacente (optionnel).
  /// [filePath] : chemin du fichier en erreur (optionnel).
  const ProjectImportError(
    this.message, {
    this.type = ProjectImportErrorType.unknown,
    this.cause,
    this.filePath,
  });

  /// Crée une erreur pour un fichier invalide.
  factory ProjectImportError.invalidFile(String filePath, {Object? cause}) {
    return ProjectImportError(
      'Le fichier sélectionné n\'est pas un fichier .mub valide.',
      type: ProjectImportErrorType.invalidFile,
      cause: cause,
      filePath: filePath,
    );
  }

  /// Crée une erreur pour un contenu JSON invalide.
  factory ProjectImportError.invalidJson(String filePath, {Object? cause}) {
    return ProjectImportError(
      'Le contenu du fichier n\'est pas un JSON valide.',
      type: ProjectImportErrorType.invalidJson,
      cause: cause,
      filePath: filePath,
    );
  }

  /// Crée une erreur pour une version de schéma non supportée.
  factory ProjectImportError.unsupportedVersion(String version, {String? filePath}) {
    return ProjectImportError(
      'La version de schéma "$version" n\'est pas supportée par cette application.',
      type: ProjectImportErrorType.unsupportedVersion,
      filePath: filePath,
    );
  }

  /// Crée une erreur pour des données corrompues.
  factory ProjectImportError.corruptData(String details, {String? filePath, Object? cause}) {
    return ProjectImportError(
      'Données corrompues : $details',
      type: ProjectImportErrorType.corruptData,
      cause: cause,
      filePath: filePath,
    );
  }

  /// Crée une erreur inconnue.
  factory ProjectImportError.unknown({String? details, String? filePath, Object? cause}) {
    return ProjectImportError(
      details ?? 'Erreur inconnue lors de l\'importation.',
      type: ProjectImportErrorType.unknown,
      cause: cause,
      filePath: filePath,
    );
  }

  /// Représentation textuelle de l'erreur.
  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('ProjectImportError: $message');
    if (type != ProjectImportErrorType.unknown) {
      buffer.write(' (type: ${type.name})');
    }
    if (filePath != null) {
      buffer.write(' [fichier: $filePath]');
    }
    if (cause != null) {
      buffer.write(' [cause: $cause]');
    }
    return buffer.toString();
  }
}