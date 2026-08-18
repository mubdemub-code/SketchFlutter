import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/errors/validation_error.dart';

/// Service d'intégration avec l'API GitHub.
///
/// Ce service permet d'utiliser le compte GitHub de l'utilisateur pour :
///   - obtenir les informations de l'utilisateur authentifié,
///   - créer un dépôt privé,
///   - uploader des fichiers (code source du projet) dans le dépôt,
///   - déclencher un workflow GitHub Actions (compilation de l'APK),
///   - télécharger l'artifact APK résultant.
///
/// L'authentification se fait via un token d'accès personnel (PAT) fourni par l'utilisateur.
/// Le token doit avoir les permissions nécessaires : `repo`, `workflow`.
///
/// Toutes les méthodes sont asynchrones et lèvent des exceptions en cas d'erreur.
/// Les réponses HTTP sont vérifiées ; les codes non-2xx génèrent une [GitHubApiException].
class GitHubService {
  /// Token d'accès personnel GitHub.
  final String token;

  /// Client HTTP injectable (pour les tests).
  final http.Client? _clientOverride;

  /// Constructeur.
  ///
  /// [token] : token GitHub de l'utilisateur.
  /// [clientOverride] : client HTTP personnalisé (optionnel).
  GitHubService({required this.token, http.Client? clientOverride})
      : _clientOverride = clientOverride;

  /// Obtient un client HTTP (soit celui injecté, soit un nouveau).
  http.Client _getClient() => _clientOverride ?? http.Client();

  /// Construit les headers HTTP de base pour l'API GitHub.
  Map<String, String> get _headers => {
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $token',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  /// Construit l'URL de base pour l'API GitHub.
  static const String _apiBase = 'https://api.github.com';

  /// Obtient les informations de l'utilisateur authentifié.
  ///
  /// Retourne une map contenant les données de l'utilisateur (login, id, etc.).
  /// Lève une [GitHubApiException] si la requête échoue.
  Future<Map<String, dynamic>> getAuthenticatedUser() async {
    final http.Client client = _getClient();
    try {
      final response = await client.get(
        Uri.parse('$_apiBase/user'),
        headers: _headers,
      );
      _checkResponse(response);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  /// Crée un dépôt privé pour l'utilisateur authentifié.
  ///
  /// [repoName] : nom du dépôt.
  /// [description] : description optionnelle.
  /// [isPrivate] : si le dépôt doit être privé (défaut true).
  ///
  /// Retourne la map du dépôt créé.
  Future<Map<String, dynamic>> createRepository({
    required String repoName,
    String? description,
    bool isPrivate = true,
  }) async {
    final http.Client client = _getClient();
    try {
      final response = await client.post(
        Uri.parse('$_apiBase/user/repos'),
        headers: _headers,
        body: jsonEncode({
          'name': repoName,
          'description': description ?? '',
          'private': isPrivate,
          'auto_init': true, // initialise avec un README
        }),
      );
      _checkResponse(response);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  /// Upload un fichier dans un dépôt GitHub (création ou mise à jour).
  ///
  /// [owner] : propriétaire du dépôt (login GitHub).
  /// [repo] : nom du dépôt.
  /// [filePath] : chemin relatif dans le dépôt (ex: `lib/main.dart`).
  /// [content] : contenu du fichier en texte brut.
  /// [commitMessage] : message de commit.
  /// [branch] : nom de la branche (défaut `main`).
  ///
  /// Si le fichier existe déjà, il sera mis à jour (nécessite le SHA actuel).
  /// Sinon, il sera créé.
  Future<void> uploadFile({
    required String owner,
    required String repo,
    required String filePath,
    required String content,
    String commitMessage = 'Upload via SketchFlutter',
    String branch = 'main',
  }) async {
    final http.Client client = _getClient();
    try {
      // Encodage du contenu en base64
      final String base64Content = base64Encode(utf8.encode(content));

      // Vérifier si le fichier existe déjà
      String? fileSha;
      try {
        final existing = await _getFileInfo(
          client: client,
          owner: owner,
          repo: repo,
          filePath: filePath,
          branch: branch,
        );
        if (existing != null) {
          fileSha = existing['sha'] as String?;
        }
      } catch (_) {
        // Ignorer si le fichier n'existe pas
      }

      // Construction du corps de la requête
      final Map<String, dynamic> body = {
        'message': commitMessage,
        'content': base64Content,
        'branch': branch,
      };
      if (fileSha != null) {
        body['sha'] = fileSha;
      }

      final response = await client.put(
        Uri.parse('$_apiBase/repos/$owner/$repo/contents/$filePath'),
        headers: _headers,
        body: jsonEncode(body),
      );
      _checkResponse(response);
    } finally {
      client.close();
    }
  }

  /// Récupère les informations d'un fichier existant (utile pour obtenir le SHA).
  ///
  /// Retourne `null` si le fichier n'existe pas.
  Future<Map<String, dynamic>?> _getFileInfo({
    required http.Client client,
    required String owner,
    required String repo,
    required String filePath,
    String branch = 'main',
  }) async {
    final response = await client.get(
      Uri.parse('$_apiBase/repos/$owner/$repo/contents/$filePath?ref=$branch'),
      headers: _headers,
    );
    if (response.statusCode == 404) {
      return null;
    }
    _checkResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Déclenche un workflow GitHub Actions (par exemple, `build_apk.yml`).
  ///
  /// [owner] : propriétaire du dépôt.
  /// [repo] : nom du dépôt.
  /// [workflowFileName] : nom du fichier de workflow (ex: `build_apk.yml`).
  /// [branch] : branche sur laquelle déclencher (défaut `main`).
  ///
  /// Retourne `true` si le déclenchement a réussi (HTTP 204).
  Future<bool> triggerWorkflow({
    required String owner,
    required String repo,
    required String workflowFileName,
    String branch = 'main',
  }) async {
    final http.Client client = _getClient();
    try {
      final response = await client.post(
        Uri.parse(
          '$_apiBase/repos/$owner/$repo/actions/workflows/$workflowFileName/dispatches',
        ),
        headers: _headers,
        body: jsonEncode({
          'ref': branch,
        }),
      );
      _checkResponse(response);
      return true;
    } finally {
      client.close();
    }
  }

  /// Télécharge l'artifact APK d'un workflow run.
  ///
  /// [owner] : propriétaire du dépôt.
  /// [repo] : nom du dépôt.
  /// [runId] : identifiant du run de workflow.
  ///
  /// Retourne les bytes de l'APK (ou null si non trouvé).
  Future<Uint8List?> downloadApkArtifact({
    required String owner,
    required String repo,
    required int runId,
  }) async {
    final http.Client client = _getClient();
    try {
      // Récupérer la liste des artifacts du run
      final artifactsResponse = await client.get(
        Uri.parse('$_apiBase/repos/$owner/$repo/actions/runs/$runId/artifacts'),
        headers: _headers,
      );
      _checkResponse(artifactsResponse);
      final artifactsData = jsonDecode(artifactsResponse.body) as Map<String, dynamic>;
      final List<dynamic> artifacts = artifactsData['artifacts'] as List<dynamic>? ?? [];

      // Chercher un artifact avec un nom contenant "apk"
      Map<String, dynamic>? apkArtifact;
      for (final artifact in artifacts) {
        final String name = (artifact as Map<String, dynamic>)['name'] as String? ?? '';
        if (name.toLowerCase().contains('apk')) {
          apkArtifact = artifact;
          break;
        }
      }

      if (apkArtifact == null) {
        return null;
      }

      // Télécharger l'archive de l'artifact
      final archiveUrl = apkArtifact['archive_download_url'] as String?;
      if (archiveUrl == null) {
        return null;
      }
      final downloadResponse = await client.get(
        Uri.parse(archiveUrl),
        headers: _headers,
      );
      _checkResponse(downloadResponse);
      // Le contenu est un zip ; il faudra l'extraire pour obtenir l'APK.
      // Pour l'instant, on retourne les bytes bruts du zip.
      return downloadResponse.bodyBytes;
    } finally {
      client.close();
    }
  }

  /// Vérifie la réponse HTTP et lève une exception si le code est >= 400.
  void _checkResponse(http.Response response) {
    if (response.statusCode >= 400) {
      throw GitHubApiException(
        message: 'Erreur GitHub API (${response.statusCode})',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }
}

/// Exception spécifique aux erreurs de l'API GitHub.
class GitHubApiException implements Exception {
  /// Message d'erreur.
  final String message;

  /// Code HTTP de la réponse.
  final int? statusCode;

  /// Corps de la réponse (pour le débogage).
  final String? responseBody;

  /// Constructeur.
  const GitHubApiException({
    required this.message,
    this.statusCode,
    this.responseBody,
  });

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('GitHubApiException: $message');
    if (statusCode != null) {
      buffer.write(' [status: $statusCode]');
    }
    if (responseBody != null) {
      buffer.write(' [body: $responseBody]');
    }
    return buffer.toString();
  }
}