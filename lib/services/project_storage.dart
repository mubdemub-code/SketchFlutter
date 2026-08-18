import 'dart:io';

import 'package:flutter/foundation.dart';

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
/// d'index (`index.json`) pour lister rapidement les projets.
///
/// **Diagnostic** : La classe intègre des journaux détaillés (debugPrint)
/// pour retracer toutes les opérations d'écriture/lecture et identifier
/// les problèmes de permissions ou de chemins.
class ProjectStorage {
  static const String projectsSubdirectory = 'projects';
  static const String indexFileName = 'index.json';

  final Directory? _baseDirectoryOverride;

  ProjectStorage({Directory? baseDirectoryOverride})
      : _baseDirectoryOverride = baseDirectoryOverride;

  // ---------------------------------------------------------------------------
  // Résolution du répertoire de stockage (avec fallback)
  // ---------------------------------------------------------------------------

  /// Obtient le répertoire racine des projets, en le créant si nécessaire.
  /// Si le répertoire par défaut échoue, tente d'utiliser le stockage externe.
  Future<Directory> _getProjectsDirectory() async {
    // 1. Si un répertoire personnalisé est fourni (tests)
    if (_baseDirectoryOverride != null) {
      await _baseDirectoryOverride!.create(recursive: true);
      debugPrint('📁 [ProjectStorage] Répertoire override: ${_baseDirectoryOverride!.path}');
      return _baseDirectoryOverride!;
    }

    // 2. Tenter le répertoire des documents (par défaut)
    try {
      final Directory documentsDir = await FileUtils.getDocumentsDirectory();
      final Directory projectsDir = Directory('${documentsDir.path}/$projectsSubdirectory');
      if (!await projectsDir.exists()) {
        await projectsDir.create(recursive: true);
        debugPrint('📁 [ProjectStorage] Dossier projets créé: ${projectsDir.path}');
      } else {
        debugPrint('📁 [ProjectStorage] Dossier projets existant: ${projectsDir.path}');
      }
      return projectsDir;
    } catch (e) {
      debugPrint('❌ [ProjectStorage] Échec création dans documents: $e');
      // 3. Fallback : stockage externe
      try {
        final Directory externalDir = await FileUtils.getExternalStorageDirectory();
        final Directory projectsDir = Directory('${externalDir.path}/$projectsSubdirectory');
        if (!await projectsDir.exists()) {
          await projectsDir.create(recursive: true);
          debugPrint('📁 [ProjectStorage] Fallback: dossier créé dans externe: ${projectsDir.path}');
        }
        return projectsDir;
      } catch (e2) {
        debugPrint('❌ [ProjectStorage] Échec création dans externe: $e2');
        rethrow;
      }
    }
  }

  /// Obtient le chemin du fichier d'index.
  Future<String> _getIndexFilePath() async {
    final Directory projectsDir = await _getProjectsDirectory();
    return '${projectsDir.path}/$indexFileName';
  }

  /// Obtient le chemin du fichier d'un projet.
  Future<String> _getProjectFilePath(String projectId) async {
    final Directory projectsDir = await _getProjectsDirectory();
    return '${projectsDir.path}/$projectId.json';
  }

  // ---------------------------------------------------------------------------
  // Gestion de l'index
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _loadIndex() async {
    final String indexPath = await _getIndexFilePath();
    debugPrint('🔍 [ProjectStorage] Chargement index: $indexPath');
    final Map<String, dynamic>? indexData = await FileUtils.readJsonFile(indexPath);
    if (indexData == null) {
      debugPrint('⚠️ [ProjectStorage] Index absent ou illisible, retour index vide.');
      return {'projects': []};
    }
    if (indexData['projects'] is! List) {
      debugPrint('⚠️ [ProjectStorage] Structure index invalide.');
      return {'projects': []};
    }
    return indexData;
  }

  Future<void> _saveIndex(Map<String, dynamic> index) async {
    final String indexPath = await _getIndexFilePath();
    debugPrint('💾 [ProjectStorage] Sauvegarde index: $indexPath');
    await FileUtils.writeJsonFile(indexPath, index, pretty: true);
    debugPrint('✅ [ProjectStorage] Index sauvegardé.');
  }

  List<Map<String, dynamic>> _extractProjectsList(Map<String, dynamic> index) {
    final dynamic projects = index['projects'];
    if (projects is List) {
      return projects.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // Opérations CRUD
  // ---------------------------------------------------------------------------

  /// Retourne la liste des métadonnées de tous les projets.
  Future<List<ProjectMetadata>> getAllProjects() async {
    debugPrint('📋 [ProjectStorage] Récupération de la liste des projets...');
    final Map<String, dynamic> index = await _loadIndex();
    final List<Map<String, dynamic>> projectsList = _extractProjectsList(index);

    if (projectsList.isEmpty) {
      debugPrint('ℹ️ [ProjectStorage] Index vide, tentative de reconstruction...');
      await _rebuildIndex();
      final newIndex = await _loadIndex();
      final rebuiltList = _extractProjectsList(newIndex);
      final List<ProjectMetadata> result = [];
      for (final map in rebuiltList) {
        try {
          result.add(ProjectMetadata.fromJson(map['metadata'] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('❌ [ProjectStorage] Erreur parsing métadonnées: $e');
        }
      }
      debugPrint('✅ [ProjectStorage] Reconstruction terminée, ${result.length} projets.');
      return result;
    }

    final List<ProjectMetadata> result = [];
    for (final map in projectsList) {
      try {
        final metadata = ProjectMetadata.fromJson(map['metadata'] as Map<String, dynamic>);
        result.add(metadata);
      } catch (e) {
        debugPrint('❌ [ProjectStorage] Erreur parsing métadonnées: $e');
      }
    }
    debugPrint('✅ [ProjectStorage] ${result.length} projets chargés depuis index.');
    return result;
  }

  /// Charge un projet complet par son identifiant.
  Future<ProjectModel?> loadProject(String projectId) async {
    debugPrint('📂 [ProjectStorage] Chargement du projet: $projectId');
    final String filePath = await _getProjectFilePath(projectId);
    debugPrint('   Chemin: $filePath');

    final bool exists = await FileUtils.fileExists(filePath);
    if (!exists) {
      debugPrint('❌ [ProjectStorage] Fichier introuvable. Liste des fichiers dans le répertoire:');
      try {
        final Directory dir = await _getProjectsDirectory();
        final files = await dir.list().toList();
        for (final f in files) {
          debugPrint('   ${f.path}');
        }
      } catch (e) {
        debugPrint('   (impossible de lister: $e)');
      }
      return null;
    }

    final Map<String, dynamic>? projectData = await FileUtils.readJsonFile(filePath);
    if (projectData == null) {
      debugPrint('❌ [ProjectStorage] Lecture JSON échouée.');
      return null;
    }

    try {
      final project = ProjectModel.fromJson(projectData);
      debugPrint('✅ [ProjectStorage] Projet chargé avec succès: ${project.metadata.name}');
      return project;
    } catch (e, stack) {
      debugPrint('❌ [ProjectStorage] Erreur parsing: $e\n$stack');
      return null;
    }
  }

  /// Sauvegarde un projet (crée ou met à jour).
  Future<void> saveProject(ProjectModel project) async {
    final projectId = project.metadata.projectId;
    if (projectId == null || projectId.isEmpty) {
      debugPrint('❌ [ProjectStorage] ERREUR: projectId null ou vide lors de la sauvegarde.');
      throw ValidationError.missingField('projectId');
    }

    debugPrint('💾 [ProjectStorage] Sauvegarde du projet: $projectId');
    final String filePath = await _getProjectFilePath(projectId);
    debugPrint('   Chemin: $filePath');

    final Map<String, dynamic> projectJson = project.toJson();
    await FileUtils.writeJsonFile(filePath, projectJson, pretty: true);
    debugPrint('✅ [ProjectStorage] Fichier projet écrit.');

    // Mise à jour de l'index
    final Map<String, dynamic> index = await _loadIndex();
    final List<Map<String, dynamic>> projectsList = _extractProjectsList(index);

    final int existingIndex = projectsList.indexWhere(
      (entry) => entry['project_id'] == projectId,
    );
    final entry = {
      'project_id': projectId,
      'file_name': '$projectId.json',
      'metadata': project.metadata.toJson(),
    };
    if (existingIndex != -1) {
      projectsList[existingIndex] = entry;
      debugPrint('ℹ️ [ProjectStorage] Entrée mise à jour dans l\'index.');
    } else {
      projectsList.add(entry);
      debugPrint('ℹ️ [ProjectStorage] Nouvelle entrée ajoutée à l\'index.');
    }

    index['projects'] = projectsList;
    await _saveIndex(index);
  }

  /// Supprime un projet.
  Future<bool> deleteProject(String projectId) async {
    debugPrint('🗑️ [ProjectStorage] Suppression du projet: $projectId');
    final String filePath = await _getProjectFilePath(projectId);
    final bool fileDeleted = await FileUtils.deleteFile(filePath);
    debugPrint('   Fichier supprimé: $fileDeleted');

    final Map<String, dynamic> index = await _loadIndex();
    final List<Map<String, dynamic>> projectsList = _extractProjectsList(index);
    final int removedCount = projectsList.length;
    projectsList.removeWhere((entry) => entry['project_id'] == projectId);
    if (projectsList.length != removedCount) {
      index['projects'] = projectsList;
      await _saveIndex(index);
      debugPrint('✅ [ProjectStorage] Projet retiré de l\'index.');
    }
    return fileDeleted;
  }

  /// Vérifie si un projet existe.
  Future<bool> projectExists(String projectId) async {
    final String filePath = await _getProjectFilePath(projectId);
    return await FileUtils.fileExists(filePath);
  }

  /// Crée un nouveau projet.
  Future<ProjectModel> createProject({
    required String name,
    String? description,
    String? author,
    String? packageName,
  }) async {
    debugPrint('🆕 [ProjectStorage] Création d\'un nouveau projet: $name');
    final ProjectModel project = ProjectModel.create(
      name: name,
      description: description,
      author: author,
      packageName: packageName,
    );
    debugPrint('   ID généré: ${project.metadata.projectId}');
    await saveProject(project);
    return project;
  }

  /// Reconstruit l'index en scannant les fichiers JSON.
  Future<void> _rebuildIndex() async {
    debugPrint('🔁 [ProjectStorage] Reconstruction de l\'index...');
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
        debugPrint('   Ajouté: ${project.metadata.name}');
      } catch (e) {
        debugPrint('❌ [ProjectStorage] Fichier illisible ignoré: ${file.path} ($e)');
      }
    }

    final Map<String, dynamic> index = {'projects': projectsList};
    await _saveIndex(index);
    debugPrint('✅ [ProjectStorage] Index reconstruit avec ${projectsList.length} projets.');
  }

  // ---------------------------------------------------------------------------
  // Méthodes de diagnostic
  // ---------------------------------------------------------------------------

  /// Teste si le répertoire de stockage est accessible en écriture.
  Future<bool> testStorageAccess() async {
    try {
      final Directory dir = await _getProjectsDirectory();
      final File testFile = File('${dir.path}/.write_test');
      await testFile.writeAsString('ok');
      await testFile.delete();
      debugPrint('✅ [ProjectStorage] Test écriture réussi dans: ${dir.path}');
      return true;
    } catch (e) {
      debugPrint('❌ [ProjectStorage] Test écriture échoué: $e');
      return false;
    }
  }

  /// Affiche l'état complet du stockage (dossier, fichiers, permissions).
  Future<void> debugStorage() async {
    debugPrint('=== DIAGNOSTIC STOCKAGE ===');
    try {
      final Directory dir = await _getProjectsDirectory();
      debugPrint('Dossier projets: ${dir.path}');
      debugPrint('Existe: ${await dir.exists()}');
      if (await dir.exists()) {
        final files = await dir.list().toList();
        debugPrint('Contenu (${files.length} éléments):');
        for (final f in files) {
          debugPrint('  - ${f.path}');
        }
      }
      await testStorageAccess();
    } catch (e) {
      debugPrint('Erreur diagnostic: $e');
    }
    debugPrint('=== FIN DIAGNOSTIC ===');
  }
}