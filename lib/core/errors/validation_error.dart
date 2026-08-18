/// Types d'erreurs possibles lors de la validation du JSON d'un projet.
enum ValidationErrorType {
  /// Un champ obligatoire est manquant.
  missingField,

  /// Le type de la valeur ne correspond pas à celui attendu.
  invalidType,

  /// La valeur est hors limites ou invalide (ex: couleur, alignement).
  invalidValue,

  /// Le type de widget ou de bloc n'est pas supporté.
  unsupportedType,

  /// Une référence (ex: @colors.xxx) est introuvable.
  invalidReference,

  /// Erreur liée au schéma lui-même.
  schemaError,

  /// Autre erreur de validation.
  other,
}

/// Exception levée lors d'une erreur de validation du JSON d'un projet.
///
/// Cette classe fournit un diagnostic détaillé : message, type d'erreur,
/// chemin exact dans le JSON (pour localiser le problème), et éventuellement
/// la cause sous-jacente.
class ValidationError implements Exception {
  /// Message décrivant l'erreur.
  final String message;

  /// Type d'erreur spécifique.
  final ValidationErrorType type;

  /// Chemin dans le JSON où l'erreur a été détectée (ex: "pages[0].root_widget.child").
  final String? path;

  /// Cause originale (exception sous-jacente), si disponible.
  final Object? cause;

  /// Informations additionnelles (contexte, valeur reçue, etc.).
  final Map<String, dynamic>? details;

  /// Constructeur principal.
  const ValidationError(
    this.message, {
    this.type = ValidationErrorType.other,
    this.path,
    this.cause,
    this.details,
  });

  /// Crée une erreur pour un champ manquant.
  factory ValidationError.missingField(
    String fieldName, {
    String? path,
  }) {
    return ValidationError(
      'Champ obligatoire manquant : $fieldName',
      type: ValidationErrorType.missingField,
      path: path,
      details: {'field': fieldName},
    );
  }

  /// Crée une erreur pour un type invalide.
  factory ValidationError.invalidType(
    String fieldName,
    String expectedType,
    String actualType, {
    String? path,
    dynamic receivedValue,
  }) {
    return ValidationError(
      'Type incorrect pour "$fieldName" : attendu $expectedType, obtenu $actualType.',
      type: ValidationErrorType.invalidType,
      path: path,
      details: {
        'field': fieldName,
        'expected': expectedType,
        'actual': actualType,
        if (receivedValue != null) 'value': receivedValue,
      },
    );
  }

  /// Crée une erreur pour une valeur invalide.
  factory ValidationError.invalidValue(
    String fieldName,
    String reason, {
    String? path,
    dynamic receivedValue,
  }) {
    return ValidationError(
      'Valeur invalide pour "$fieldName" : $reason',
      type: ValidationErrorType.invalidValue,
      path: path,
      details: {
        'field': fieldName,
        'reason': reason,
        if (receivedValue != null) 'value': receivedValue,
      },
    );
  }

  /// Crée une erreur pour un type (widget, bloc) non supporté.
  factory ValidationError.unsupportedType(
    String typeName,
    String category, {
    String? path,
  }) {
    return ValidationError(
      '$category non supporté(e) : $typeName',
      type: ValidationErrorType.unsupportedType,
      path: path,
      details: {'type': typeName, 'category': category},
    );
  }

  /// Crée une erreur pour une référence introuvable.
  factory ValidationError.invalidReference(
    String reference, {
    String? path,
  }) {
    return ValidationError(
      'Référence introuvable : $reference',
      type: ValidationErrorType.invalidReference,
      path: path,
      details: {'reference': reference},
    );
  }

  /// Crée une erreur de schéma générique.
  factory ValidationError.schemaError(
    String message, {
    String? path,
    Object? cause,
  }) {
    return ValidationError(
      message,
      type: ValidationErrorType.schemaError,
      path: path,
      cause: cause,
    );
  }

  /// Crée une erreur générique.
  factory ValidationError.other(
    String message, {
    String? path,
    Object? cause,
    Map<String, dynamic>? details,
  }) {
    return ValidationError(
      message,
      type: ValidationErrorType.other,
      path: path,
      cause: cause,
      details: details,
    );
  }

  /// Représentation textuelle détaillée de l'erreur.
  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('ValidationError: $message');
    if (type != ValidationErrorType.other) {
      buffer.write(' [type: ${type.name}]');
    }
    if (path != null) {
      buffer.write(' [path: $path]');
    }
    if (details != null && details!.isNotEmpty) {
      buffer.write(' [details: $details]');
    }
    if (cause != null) {
      buffer.write(' [cause: $cause]');
    }
    return buffer.toString();
  }
}