import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../core/errors/validation_error.dart';
import '../models/project_model.dart';
import 'github_service.dart';

/// Interface de génération de code source à partir d'un projet.
abstract class IProjectCodeGenerator {
  Map<String, String> generate(ProjectModel project);
}

/// Backend de compilation abstrait.
abstract class CompilationBackend {
  Future<CompilationResult> compile(
    ProjectModel project,
    IProjectCodeGenerator codeGenerator,
  );
}

/// Résultat d'une compilation.
class CompilationResult {
  final bool success;
  final String message;
  final String? apkFilePath;
  final int? runId;

  const CompilationResult({
    required this.success,
    required this.message,
    this.apkFilePath,
    this.runId,
  });

  factory CompilationResult.success(String apkFilePath, {int? runId}) {
    return CompilationResult(
      success: true,
      message: 'Compilation réussie',
      apkFilePath: apkFilePath,
      runId: runId,
    );
  }

  factory CompilationResult.failure(String message) {
    return CompilationResult(
      success: false,
      message: message,
    );
  }
}

/// Backend de compilation utilisant GitHub Actions.
class GitHubCompilationBackend implements CompilationBackend {
  final GitHubService githubService;
  final String repoPrefix;
  final bool cleanupAfterCompile;
  final Duration timeout;
  final Duration pollInterval;

  GitHubCompilationBackend({
    required this.githubService,
    this.repoPrefix = 'sketchflutter-build-',
    this.cleanupAfterCompile = true,
    this.timeout = const Duration(minutes: 20),
    this.pollInterval = const Duration(seconds: 15),
  });

  @override
  Future<CompilationResult> compile(
    ProjectModel project,
    IProjectCodeGenerator codeGenerator,
  ) async {
    // 1. Générer le code source
    Map<String, String> sourceFiles;
    try {
      sourceFiles = codeGenerator.generate(project);
    } catch (e) {
      return CompilationResult.failure('Erreur de génération du code : $e');
    }

    if (sourceFiles.isEmpty) {
      return CompilationResult.failure('Aucun fichier généré');
    }

    // 2. Créer un dépôt unique
    final String repoName =
        '$repoPrefix${project.metadata.projectId}'.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    Map<String, dynamic> repo;
    try {
      repo = await githubService.createRepository(
        repoName: repoName,
        description: 'Build généré par SketchFlutter pour ${project.metadata.name}',
        isPrivate: true,
      );
    } on GitHubApiException catch (e) {
      return CompilationResult.failure('Échec de création du dépôt : ${e.message}');
    }

    final String owner = repo['owner']['login'] as String;
    final String repoFullName = repo['full_name'] as String;

    try {
      // 3. Uploader les fichiers du projet
      for (final entry in sourceFiles.entries) {
        await githubService.uploadFile(
          owner: owner,
          repo: repoName,
          filePath: entry.key,
          content: entry.value,
          commitMessage: 'Add ${entry.key} via SketchFlutter',
        );
      }

      // 4. Uploader le workflow si non présent
      final workflowContent = _buildWorkflowContent();
      await githubService.uploadFile(
        owner: owner,
        repo: repoName,
        filePath: '.github/workflows/build_apk.yml',
        content: workflowContent,
        commitMessage: 'Add build workflow via SketchFlutter',
      );

      // 5. Déclencher le workflow
      final bool dispatched = await githubService.triggerWorkflow(
        owner: owner,
        repo: repoName,
        workflowFileName: 'build_apk.yml',
      );
      if (!dispatched) {
        return CompilationResult.failure('Échec du déclenchement du workflow');
      }

      // 6. Surveiller le run jusqu'à terminaison
      final int? runId = await _waitForWorkflowCompletion(
        owner: owner,
        repo: repoName,
      );
      if (runId == null) {
        return CompilationResult.failure('Workflow introuvable ou timeout dépassé');
      }

      // Vérifier la conclusion du run
      final conclusion = await _getRunConclusion(owner: owner, repo: repoName, runId: runId);
      if (conclusion != 'success') {
        if (cleanupAfterCompile) {
          await _deleteRepository(owner: owner, repo: repoName);
        }
        return CompilationResult.failure('Le workflow a échoué (conclusion: $conclusion)');
      }

      // 7. Télécharger l'artifact APK (zip)
      final Uint8List? apkArtifactZip = await githubService.downloadApkArtifact(
        owner: owner,
        repo: repoName,
        runId: runId,
      );
      if (apkArtifactZip == null) {
        if (cleanupAfterCompile) {
          await _deleteRepository(owner: owner, repo: repoName);
        }
        return CompilationResult.failure('Aucun artifact APK trouvé');
      }

      // 8. Extraire l'APK du zip
      final String apkPath = await _extractApkFromZip(apkArtifactZip, project.metadata.name);
      if (apkPath == null) {
        if (cleanupAfterCompile) {
          await _deleteRepository(owner: owner, repo: repoName);
        }
        return CompilationResult.failure('Impossible d\'extraire l\'APK du zip');
      }

      // 9. Optionnellement supprimer le dépôt
      if (cleanupAfterCompile) {
        await _deleteRepository(owner: owner, repo: repoName);
      }

      return CompilationResult.success(apkPath, runId: runId);
    } on GitHubApiException catch (e) {
      return CompilationResult.failure('Erreur GitHub : ${e.message}');
    } catch (e) {
      return CompilationResult.failure('Erreur inattendue : $e');
    }
  }

  // ------------------ Méthodes privées ------------------

  String _buildWorkflowContent() {
    return '''
name: build_apk

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
      - run: flutter pub get
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v4
        with:
          name: app-release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
''';
  }

  /// Attend que le workflow soit terminé et retourne le runId.
  Future<int?> _waitForWorkflowCompletion({
    required String owner,
    required String repo,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final runs = await _getWorkflowRuns(owner: owner, repo: repo);
      if (runs.isNotEmpty) {
        // Prendre le run le plus récent
        final run = runs.first;
        final status = run['status'] as String?;
        final conclusion = run['conclusion'] as String?;
        if (status == 'completed' || conclusion != null) {
          return run['id'] as int?;
        }
      }
      await Future.delayed(pollInterval);
    }
    return null;
  }

  /// Récupère la liste des runs du workflow.
  Future<List<Map<String, dynamic>>> _getWorkflowRuns({
    required String owner,
    required String repo,
  }) async {
    final token = githubService.token;
    final headers = {
      'Accept': 'application/vnd.github+json',
      'Authorization': 'Bearer $token',
      'X-GitHub-Api-Version': '2022-11-28',
    };
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$owner/$repo/actions/runs'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw GitHubApiException(
        message: 'Erreur lors de la récupération des runs (${response.statusCode})',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final runs = data['workflow_runs'] as List<dynamic>? ?? [];
    return runs.cast<Map<String, dynamic>>();
  }

  /// Récupère la conclusion d'un run spécifique.
  Future<String?> _getRunConclusion({
    required String owner,
    required String repo,
    required int runId,
  }) async {
    final runs = await _getWorkflowRuns(owner: owner, repo: repo);
    for (final run in runs) {
      if (run['id'] == runId) {
        return run['conclusion'] as String?;
      }
    }
    return null;
  }

  /// Supprime le dépôt après la compilation.
  Future<void> _deleteRepository({
    required String owner,
    required String repo,
  }) async {
    final token = githubService.token;
    final headers = {
      'Accept': 'application/vnd.github+json',
      'Authorization': 'Bearer $token',
      'X-GitHub-Api-Version': '2022-11-28',
    };
    final response = await http.delete(
      Uri.parse('https://api.github.com/repos/$owner/$repo'),
      headers: headers,
    );
    if (response.statusCode != 204 && response.statusCode != 404) {
      // Ignorer si déjà supprimé
    }
  }

  /// Extrait l'APK d'un zip téléchargé (contient un dossier d'artifact avec l'APK).
  Future<String?> _extractApkFromZip(Uint8List zipBytes, String projectName) async {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      ArchiveFile? apkFile;
      for (final file in archive) {
        if (file.name.endsWith('.apk')) {
          apkFile = file;
          break;
        }
      }
      if (apkFile == null) return null;

      // Sauvegarder dans le répertoire des documents de l'application
      final documentsDir = await getApplicationDocumentsDirectory();
      final outputDir = Directory('${documentsDir.path}/apk_outputs');
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      final safeName = projectName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final apkPath = '${outputDir.path}/$safeName.apk';
      final file = File(apkPath);
      await file.writeAsBytes(apkFile.content as Uint8List);
      return apkPath;
    } catch (e) {
      return null;
    }
  }
}

/// Service de compilation central.
class CompileService {
  final CompilationBackend backend;
  final IProjectCodeGenerator codeGenerator;

  const CompileService({
    required this.backend,
    required this.codeGenerator,
  });

  Future<CompilationResult> compile(ProjectModel project) {
    return backend.compile(project, codeGenerator);
  }
}