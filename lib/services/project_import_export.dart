import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/constants/schema_versions.dart';
import '../core/errors/project_import_error.dart';
import '../core/errors/validation_error.dart';
import '../core/utils/file_utils.dart';
import '../core/utils/json_utils.dart';
import '../models/project_model.dart';

/// Service d'import et d'export de projets SketchFlutter au format `.mub`.
///
/// Le format `.mub` est un fichier texte contenant un en-tête magique,
/// suivi d'une charge utile JSON compressée en gzip puis encodée en base64.
///
/// Format :
/// ```
/// SKETCHFLUTTER_MUB_1.0:<base64(gzip(json))>
/// ```
///
/// Ce service fournit des méthodes pour :
///   - exporter un projet vers un fichier `.mub`.
///   - exporter un projet vers une chaîne base64 (pour partage direct).
///   - importer un projet depuis un fichier `.mub`.
///   - importer un projet depuis une chaîne base64.
///
/// Toutes les erreurs d'import sont remontées via [ProjectImportError].
class ProjectImportExport {
  /// En-tête magique du format de fichier.
  static const String magicHeader = 'SKETCHFLUTTER_MUB_1.0:';

  /// Vérifie si le contenu commence par l'en-tête magique.
  static bool _hasValidHeader(String content) {
    return content.startsWith(magicHeader);
  }

  /// Extrait la charge utile base64 après l'en-tête.
  static String _extractPayload(String content) {
    if (!_hasValidHeader(content)) {
      throw ProjectImportError.invalidFile('', cause: 'En-tête MUB manquant');
    }
    return content.substring(magicHeader.length);
  }

  /// Compresse une chaîne JSON en bytes gzip.
  static Uint8List _compressJson(String jsonString) {
    final bytes = utf8.encode(jsonString);
    final encoder = ZLibEncoder(gzip: true, level: 9);
    return Uint8List.fromList(encoder.convert(bytes));
  }

  /// Décompresse des bytes gzip en chaîne UTF-8.
  static String _decompressJson(Uint8List gzipBytes) {
    final decoder = ZLibDecoder(gzip: true);
    final bytes = decoder.convert(gzipBytes);
    return utf8.decode(bytes);
  }

  /// Encode des bytes gzip en base64.
  static String _encodeToBase64(Uint8List gzipBytes) {
    return base64Encode(gzipBytes);
  }

  /// Décode une chaîne base64 en bytes gzip.
  static Uint8List _decodeFromBase64(String base64String) {
    return base64Decode(base64String);
  }

  /// Sérialise un [ProjectModel] en chaîne `.mub` (contenu complet).
  static String _projectToMubString(ProjectModel project) {
    // 1. Convertir le projet en map JSON
    final Map<String, dynamic> projectJson = project.toJson();
    // 2. Sérialiser en chaîne JSON compacte
    final String jsonString = const JsonEncoder().convert(projectJson);
    // 3. Compresser en gzip
    final Uint8List gzipBytes = _compressJson(jsonString);
    // 4. Encoder en base64
    final String base64Payload = _encodeToBase64(gzipBytes);
    // 5. Assembler avec l'en-tête
    return '$magicHeader$base64Payload';
  }

  /// Désérialise une chaîne `.mub` en [ProjectModel].
  static ProjectModel _mubStringToProject(String mubString) {
    // 1. Extraire la charge utile base64
    final String base64Payload = _extractPayload(mubString);
    // 2. Décoder la base64 en bytes gzip
    final Uint8List gzipBytes;
    try {
      gzipBytes = _decodeFromBase64(base64Payload);
    } catch (e) {
      throw ProjectImportError.invalidJson('', cause: e);
    }
    // 3. Décompresser en chaîne JSON
    final String jsonString;
    try {
      jsonString = _decompressJson(gzipBytes);
    } catch (e) {
      throw ProjectImportError.corruptData('Décompression gzip échouée', cause: e);
    }
    // 4. Parser la chaîne JSON en map
    final Map<String, dynamic>? projectJson;
    try {
      projectJson = JsonUtils.tryParse(jsonString);
    } catch (e) {
      throw ProjectImportError.invalidJson('', cause: e);
    }
    if (projectJson == null) {
      throw ProjectImportError.invalidJson('', cause: 'Parsing JSON échoué');
    }
    // 5. Vérifier la version du schéma
    final String? schemaVersion = projectJson['schema_version'] as String?;
    if (schemaVersion != null && !SchemaVersions.isSupported(schemaVersion)) {
      throw ProjectImportError.unsupportedVersion(schemaVersion);
    }
    // 6. Créer le modèle
    try {
      return ProjectModel.fromJson(projectJson);
    } on ValidationError catch (e) {
      throw ProjectImportError.corruptData('Validation du projet échouée', cause: e);
    } catch (e) {
      throw ProjectImportError.unknown(cause: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Exporte un projet vers une chaîne base64 encodée (prête à être partagée).
  ///
  /// Cette chaîne peut être envoyée par email, messagerie, ou stockée comme texte.
  /// Elle contient l'en-tête magique et la charge utile.
  static String exportToBase64String(ProjectModel project) {
    return _projectToMubString(project);
  }

  /// Exporte un projet vers un fichier `.mub` sur le disque.
  ///
  /// [project] : le projet à exporter.
  /// [filePath] : chemin de destination du fichier `.mub`.
  /// Si [filePath] est null, un fichier temporaire est créé et son chemin est retourné.
  ///
  /// Retourne le chemin du fichier créé.
  static Future<String> exportToFile(
    ProjectModel project, {
    String? filePath,
  }) async {
    final String mubContent = _projectToMubString(project);

    if (filePath == null) {
      // Créer un fichier temporaire
      final Directory tempDir = await FileUtils.getTemporaryDirectory();
      final String fileName =
          '${project.metadata.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.mub';
      filePath = '${tempDir.path}/$fileName';
    }

    await FileUtils.writeTextFile(filePath, mubContent);
    return filePath;
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Importe un projet depuis une chaîne base64 encodée.
  ///
  /// [mubString] : la chaîne contenant l'en-tête et la charge utile.
  /// Retourne un [ProjectModel].
  static ProjectModel importFromBase64String(String mubString) {
    try {
      return _mubStringToProject(mubString);
    } on ProjectImportError {
      rethrow;
    } catch (e) {
      throw ProjectImportError.unknown(cause: e);
    }
  }

  /// Importe un projet depuis un fichier `.mub`.
  ///
  /// [filePath] : chemin du fichier `.mub` à importer.
  /// Retourne un [ProjectModel].
  static Future<ProjectModel> importFromFile(String filePath) async {
    // Vérifier l'extension du fichier
    if (!filePath.toLowerCase().endsWith('.mub')) {
      throw ProjectImportError.invalidFile(filePath);
    }

    // Lire le contenu du fichier
    final String? content = await FileUtils.readTextFile(filePath);
    if (content == null) {
      throw ProjectImportError.invalidFile(filePath, cause: 'Fichier introuvable');
    }

    // Vérifier l'en-tête
    if (!_hasValidHeader(content)) {
      throw ProjectImportError.invalidFile(filePath, cause: 'En-tête MUB manquant ou invalide');
    }

    try {
      return _mubStringToProject(content);
    } on ProjectImportError catch (e) {
      // Rejeter avec le chemin du fichier pour plus de contexte
      throw ProjectImportError(
        e.message,
        type: e.type,
        cause: e.cause,
        filePath: filePath,
      );
    } catch (e) {
      throw ProjectImportError.unknown(
        filePath: filePath,
        cause: e,
      );
    }
  }
}