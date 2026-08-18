import 'dart:io';

import '../core/errors/validation_error.dart';
import '../core/utils/file_utils.dart';
import '../core/utils/json_utils.dart';
import '../core/utils/uuid_generator.dart';
import '../models/project_model.dart';
import '../models/project_metadata.dart';

/// Service de sauvegarde et de chargement local des projets SketchFlutter.
///
/// Ce service gère la persistance des projets sous forme de fichiers JSON
/// dans le répertoire des documents de l'application. Il utilise un fichier
/// d'index (`index.json`) pour lister rapidement les projets sans devoir
/// charger tous les fichiers.
///
/// Structure de stockage :
///   `<appDocuments>/projects/`          (répertoire racine)
///   ├── index.json                      (index des projets)
///   ├── <project_id>.json               (fichier de chaque projet)
///   └── ...
///
/// Le service est utilisé par les providers et les écrans pour :
///   - lister les projets (écran d'accueil),
///   - ouvrir un projet (chargement complet),
///   - enregistrer un projet (création ou mise à jour),
///   - supprimer un projet.
class ProjectStorage {
  /// Nom du sous-répertoire où sont stockés les projets.
  static const String projectsSubdirectory = 'projects';

  /// Nom du fichier d'index.
  static const String indexFileName = 'index.json';

  /// Répertoire racine des projets (peut être injecté pour les tests).
  final Directory? _baseDirectoryOverride;

  /// Constructeur.
  ///
  /// [baseDirectoryOverride] : répertoire personnalisé (utile pour les tests).
  /// Par défaut, le répertoire sera `<documents>/projects`.
  ProjectStorage({Directory? baseDirectoryOverride})
      : _baseDirectoryOverride = baseDirectoryOverride;

  /// Obtient le répertoire racine des projets, en le créant si nécessaire.
  Future<Directory> _getProjectsDirectory() async {
    if (_baseDirectoryOverride != null) {
      await _baseDirectoryOverride!.create(recursive: true);
      return _baseDirectoryOverride!;
    }
    final Directory documentsDir = await FileUtils.getDocumentsDirectory();
    final Directory projectsDir = Directory(
      '${documentsDir.path}/$projectsSubdirectory',
    );
    if (!await projectsDir.exists()) {
      await projectsDir.create(recursive: true);
    }
    return projectsDir;
  }

  /// Obtient le chemin complet du fichier d'index.
  Future<String> _getIndexFilePath() async {
    final Directory projectsDir = await _getProjectsDirectory();
    return '${projectsDir.path}/$indexFileName';
  }

  /// Obtient le chemin complet du fichier d'un projet.
  Future<String> _getProjectFilePath(String projectId) async {
    final Directory projectsDir = await _getProjectsDirectory();
    return '${projectsDir.path}/$projectId.json';
  }

  /// Charge l'index des projets depuis le fichier `index.json`.
  ///
  /// Retourne une map avec la clé `projects` contenant la liste des métadonnées.
  /// Si le fichier n'existe pas ou est corrompu, retourne un index vide.
  Future<Map<String, dynamic>> _loadIndex() async {
    final String indexPath = await _getIndexFilePath();
    final Map<String, dynamic>? indexData = await FileUtils.readJsonFile(indexPath);
    if (indexData == null) {
      return {'projects': []};
    }
    // Vérification basique de la structure
    if (indexData['projects'] is! List) {
      return {'projects': []};
    }
    return indexData;
  }

  /// Sauvegarde l'index complet dans le fichier `index.json`.
  Future<void> _saveIndex(Map<String, dynamic> index) async {
    final String indexPath = await _getIndexFilePath();
    await FileUtils.writeJsonFile(indexPath, index, pretty: true);
  }

  /// Extrait la liste des métadonnées depuis l'index.
  List<Map<String, dynamic>> _extractProjectsList(Map<String, dynamic> index) {
    final dynamic projects = index['projects'];
    if (projects is List) {
      return projects.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Retourne la liste de tous les projets (métadonnées uniquement).
  ///
  /// Utilise l'index pour une lecture rapide ; si l'index est absent,
  /// tente de reconstruire l'index en scannant les fichiers JSON.
  Future<List<ProjectMetadata>> getAllProjects() async {
    final Map<String, dynamic> index = await _loadIndex();
    final List<Map<String, dynamic>> projectsList = _extractProjectsList(index);

    if (projectsList.isEmpty) {
      // Tenter de reconstruire l'index à partir des fichiers existants
      await _rebuildIndex();
      final newIndex = await _loadIndex();
      final rebuiltList = _extractProjectsList(newIndex);
      final List<ProjectMetadata> result = [];
      for (final map in rebuiltList) {
        try {
          result.add(ProjectMetadata.fromJson(map['metadata'] as Map<String, dynamic>));
        } catch (_) {
          // Ignorer les entrées invalides
        }
      }
      return result;
    }

    final List<ProjectMetadata> result = [];
    for (final map in projectsList) {
      try {
        final metadata = ProjectMetadata.fromJson(map['metadata'] as Map<String, dynamic>);
        result.add(metadata);
      } catch (_) {
        // Ignorer les entrées corrompues
      }
    }
    return result;
  }

  /// Charge un projet complet par son identifiant.
  ///
  /// Retourne `null` si le projet n'existe pas ou si une erreur survient.
  Future<ProjectModel?> loadProject(String projectId) async {
    final String filePath = await _getProjectFilePath(projectId);
    final Map<String, dynamic>? projectData = await FileUtils.readJsonFile(filePath);
    if (projectData == null) {
      return null;
    }
    try {
      return ProjectModel.fromJson(projectData);
    } catch (_) {
      return null;
    }
  }

  /// Sauvegarde un projet (crée ou met à jour selon l'identifiant).
  ///
  /// Après sauvegarde, l'index est mis à jour avec les métadonnées du projet.
  Future<void> saveProject(ProjectModel project) async {
    final String filePath = await _getProjectFilePath(project.metadata.projectId!);
    final Map<String, dynamic> projectJson = project.toJson();
    await FileUtils.writeJsonFile(filePath, projectJson, pretty: true);

    // Mettre à jour l'index
    final Map<String, dynamic> index = await _loadIndex();
    final List<Map<String, dynamic>> projectsList = _extractProjectsList(index);

    // Mettre à jour ou ajouter l'entrée correspondante
    final String projectId = project.metadata.projectId!;
    final int existingIndex = projectsList.indexWhere(
      (entry) => entry['project_id'] == projectId,
    );
    if (existingIndex != -1) {
      projectsList[existingIndex] = {
        'project_id': projectId,
        'file_name': '$projectId.json',
        'metadata': project.metadata.toJson(),
      };
    } else {
      projectsList.add({
        'project_id': projectId,
        'file_name': '$projectId.json',
        'metadata': project.metadata.toJson(),
      });
    }

    index['projects'] = projectsList;
    await _saveIndex(index);
  }

  /// Supprime un projet par son identifiant.
  ///
  /// Supprime le fichier du projet et retire son entrée de l'index.
  /// Retourne `true` si le projet a été supprimé, `false` s'il n'existait pas.
  Future<bool> deleteProject(String projectId) async {
    final String filePath = await _getProjectFilePath(projectId);
    final bool fileDeleted = await FileUtils.deleteFile(filePath);

    // Mettre à jour l'index
    final Map<String, dynamic> index = await _loadIndex();
    final List<Map<String, dynamic>> projectsList = _extractProjectsList(index);
    final int removedCount = projectsList.length;
    projectsList.removeWhere((entry) => entry['project_id'] == projectId);
    if (projectsList.length != removedCount) {
      index['projects'] = projectsList;
      await _saveIndex(index);
    }

    return fileDeleted;
  }

  /// Vérifie si un projet avec cet identifiant existe.
  Future<bool> projectExists(String projectId) async {
    final String filePath = await _getProjectFilePath(projectId);
    return await FileUtils.fileExists(filePath);
  }

  /// Crée un nouveau projet vide avec les métadonnées fournies.
  ///
  /// Retourne le projet créé (déjà sauvegardé sur disque).
  Future<ProjectModel> createProject({
    required String name,
    String? description,
    String? author,
    String? packageName,
  }) async {
    final ProjectModel project = ProjectModel.create(
      name: name,
      description: description,
      author: author,
      packageName: packageName,
    );
    await saveProject(project);
    return project;
  }

  /// Reconstruit l'index en scannant les fichiers JSON du répertoire.
  ///
  /// Utile si le fichier `index.json` est manquant ou corrompu.
  /// Pour chaque fichier `.json` (sauf `index.json`), tente de charger le projet
  /// et d'en extraire les métadonnées.
  Future<void> _rebuildIndex() async {
    final Directory projectsDir = await _getProjectsDirectory();
    final List<File> files = await FileUtils.listFiles(
      projectsDir.path,
      extension: '.json',
    );

    final List<Map<String, dynamic>> projectsList = [];
    for (final File file in files) {
      if (file.path.endsWith(indexFileName)) continue;
      try {
        final Map<String, dynamic>? projectData = await FileUtils.readJsonFile(file.path);
        if (projectData == null) continue;
        final ProjectModel project = ProjectModel.fromJson(projectData);
        projectsList.add({
          'project_id': project.metadata.projectId,
          'file_name': file.uri.pathSegments.last,
          'metadata': project.metadata.toJson(),
        });
      } catch (_) {
        // Ignorer les fichiers illisibles
      }
    }

    final Map<String, dynamic> index = {'projects': projectsList};
    await _saveIndex(index);
  }
}