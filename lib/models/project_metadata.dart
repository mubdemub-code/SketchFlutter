import 'dart:convert';

import '../core/errors/validation_error.dart';
import '../core/utils/json_utils.dart';
import '../core/utils/uuid_generator.dart';

/// Métadonnées d'un projet SketchFlutter.
///
/// Cette classe contient les informations générales du projet, indépendamment
/// de son contenu (pages, variables, assets...). Elle est sérialisable en JSON
/// pour être incluse dans le fichier `.mub` ou sauvegardée localement.
///
/// Tous les champs sont immuables ; utilisez [copyWith] pour créer des copies modifiées.
class ProjectMetadata {
  /// Nom du projet.
  final String name;

  /// Description optionnelle.
  final String? description;

  /// Nom de l'auteur (peut être le pseudonyme de l'utilisateur).
  final String? author;

  /// Date de création au format ISO 8601 (ex: "2025-01-01T12:00:00Z").
  final DateTime createdAt;

  /// Date de dernière modification au format ISO 8601.
  final DateTime updatedAt;

  /// Miniature du projet (capture d'écran) encodée en base64.
  /// Peut être `null` si aucune miniature n'a été générée.
  final String? thumbnailBase64;

  /// Identifiant unique du projet (utile pour la synchronisation).
  final String? projectId;

  /// Constructeur principal.
  ///
  /// [name] : nom du projet (ne doit pas être vide).
  /// [createdAt] : date de création (par défaut maintenant).
  /// [updatedAt] : date de modification (par défaut maintenant).
  const ProjectMetadata({
    required this.name,
    this.description,
    this.author,
    required this.createdAt,
    required this.updatedAt,
    this.thumbnailBase64,
    this.projectId,
  });

  /// Crée une instance avec les valeurs par défaut pour un nouveau projet.
  ///
  /// [name] : nom du projet.
  /// [description] : description optionnelle.
  /// [author] : auteur optionnel.
  factory ProjectMetadata.create({
    required String name,
    String? description,
    String? author,
  }) {
    if (name.trim().isEmpty) {
      throw ValidationError.missingField('name');
    }
    final now = DateTime.now().toUtc();
    return ProjectMetadata(
      name: name.trim(),
      description: description?.trim(),
      author: author?.trim(),
      createdAt: now,
      updatedAt: now,
      projectId: UuidGenerator.generateProjectId(),
    );
  }

  /// Crée une instance à partir d'une map JSON.
  ///
  /// [json] : la map contenant les métadonnées.
  /// Lève une [ValidationError] si des champs obligatoires sont manquants ou invalides.
  factory ProjectMetadata.fromJson(Map<String, dynamic> json) {
    // Nom obligatoire
    final String? name = JsonUtils.getString(json, 'name');
    if (name == null || name.trim().isEmpty) {
      throw ValidationError.missingField('name', path: 'project_metadata');
    }

    // Description optionnelle
    final String? description = JsonUtils.getString(json, 'description');

    // Auteur optionnel
    final String? author = JsonUtils.getString(json, 'author');

    // Dates (obligatoires)
    final String? createdAtStr = JsonUtils.getString(json, 'created_at');
    final String? updatedAtStr = JsonUtils.getString(json, 'updated_at');

    DateTime createdAt;
    DateTime updatedAt;

    if (createdAtStr != null) {
      createdAt = DateTime.tryParse(createdAtStr)?.toUtc() ?? DateTime.now().toUtc();
    } else {
      createdAt = DateTime.now().toUtc();
    }

    if (updatedAtStr != null) {
      updatedAt = DateTime.tryParse(updatedAtStr)?.toUtc() ?? createdAt;
    } else {
      updatedAt = createdAt;
    }

    // Miniature
    final String? thumbnail = JsonUtils.getString(json, 'thumbnail');

    // Identifiant
    final String? projectId = JsonUtils.getString(json, 'project_id');

    return ProjectMetadata(
      name: name.trim(),
      description: description,
      author: author,
      createdAt: createdAt,
      updatedAt: updatedAt,
      thumbnailBase64: thumbnail,
      projectId: projectId,
    );
  }

  /// Convertit l'objet en map JSON.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (author != null) 'author': author,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (thumbnailBase64 != null) 'thumbnail': thumbnailBase64,
      if (projectId != null) 'project_id': projectId,
    };
  }

  /// Crée une copie de l'objet en remplaçant certains champs.
  ProjectMetadata copyWith({
    String? name,
    String? description,
    String? author,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? thumbnailBase64,
    String? projectId,
  }) {
    return ProjectMetadata(
      name: name ?? this.name,
      description: description ?? this.description,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      thumbnailBase64: thumbnailBase64 ?? this.thumbnailBase64,
      projectId: projectId ?? this.projectId,
    );
  }

  /// Met à jour la date de modification avec la date/heure actuelle.
  ProjectMetadata touch() {
    return copyWith(updatedAt: DateTime.now().toUtc());
  }

  /// Vérifie si l'objet est valide (nom non vide, dates cohérentes).
  bool isValid() {
    return name.trim().isNotEmpty &&
        createdAt.isBefore(updatedAt) == false; // createdAt <= updatedAt
  }

  @override
  String toString() => 'ProjectMetadata(name: $name, id: $projectId)';
}