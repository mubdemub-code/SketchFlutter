import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart' as path_provider;

/// Utilitaires pour la gestion des fichiers locaux.
///
/// Cette classe centralise toutes les opérations de lecture/écriture sur le système
/// de fichiers du téléphone. Elle est utilisée notamment pour :
///   - sauvegarder les projets JSON dans le stockage interne,
///   - exporter/importer les fichiers `.mub`,
///   - gérer les assets (images) encodés en base64.
class FileUtils {
  /// Obtient le répertoire de documents de l'application.
  /// Sur Android, c'est généralement `/data/user/0/<package>/app_flutter`.
  static Future<Directory> getDocumentsDirectory() async {
    try {
      return await path_provider.getApplicationDocumentsDirectory();
    } catch (e) {
      throw FileSystemException('Impossible d\'obtenir le répertoire des documents', e.toString());
    }
  }

  /// Obtient le répertoire temporaire.
  static Future<Directory> getTemporaryDirectory() async {
    try {
      return await path_provider.getTemporaryDirectory();
    } catch (e) {
      throw FileSystemException('Impossible d\'obtenir le répertoire temporaire', e.toString());
    }
  }

  /// Obtient le répertoire de stockage externe de l'application.
  /// Sur Android, retourne généralement `/storage/emulated/0/Android/data/<package>/files`.
  /// Ce répertoire est privé à l'application mais situé sur le stockage externe.
  static Future<Directory> getExternalStorageDirectory() async {
    try {
      final Directory? dir = await path_provider.getExternalStorageDirectory();
      if (dir == null) {
        throw FileSystemException('Répertoire de stockage externe introuvable');
      }
      return dir;
    } catch (e) {
      throw FileSystemException('Impossible d\'obtenir le répertoire externe', e.toString());
    }
  }

  /// Crée un répertoire (et ses parents si nécessaire).
  static Future<Directory> createDirectory(String path) async {
    final Directory dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Vérifie si un fichier existe.
  static Future<bool> fileExists(String path) async {
    return await File(path).exists();
  }

  /// Vérifie si un répertoire existe.
  static Future<bool> directoryExists(String path) async {
    return await Directory(path).exists();
  }

  /// Écrit une chaîne de caractères dans un fichier.
  /// Par défaut, l'encodage est UTF-8.
  static Future<File> writeTextFile(
    String path,
    String content, {
    bool createDirectories = true,
  }) async {
    if (createDirectories) {
      final dir = Directory(File(path).parent.path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
    final File file = File(path);
    return await file.writeAsString(content, encoding: utf8);
  }

  /// Écrit des données binaires (octets) dans un fichier.
  static Future<File> writeBinaryFile(
    String path,
    Uint8List bytes, {
    bool createDirectories = true,
  }) async {
    if (createDirectories) {
      final dir = Directory(File(path).parent.path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
    final File file = File(path);
    return await file.writeAsBytes(bytes);
  }

  /// Lit un fichier texte et retourne son contenu sous forme de chaîne.
  static Future<String?> readTextFile(String path) async {
    final File file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return await file.readAsString(encoding: utf8);
  }

  /// Lit un fichier binaire et retourne ses octets.
  static Future<Uint8List?> readBinaryFile(String path) async {
    final File file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return await file.readAsBytes();
  }

  /// Lit un fichier JSON et le convertit en [Map<String, dynamic>].
  /// Retourne `null` si le fichier n'existe pas ou si le parsing échoue.
  static Future<Map<String, dynamic>?> readJsonFile(String path) async {
    final String? content = await readTextFile(path);
    if (content == null) return null;
    try {
      final dynamic decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Écrit un [Map] sous forme de fichier JSON.
  /// Si [pretty] est vrai, le JSON est indenté pour la lisibilité.
  static Future<File> writeJsonFile(
    String path,
    Map<String, dynamic> data, {
    bool pretty = false,
    bool createDirectories = true,
  }) async {
    final encoder = JsonEncoder.withIndent(pretty ? '  ' : null);
    final String jsonString = encoder.convert(data);
    return await writeTextFile(
      path,
      jsonString,
      createDirectories: createDirectories,
    );
  }

  /// Supprime un fichier s'il existe.
  /// Retourne `true` si le fichier a été supprimé, `false` s'il n'existait pas.
  static Future<bool> deleteFile(String path) async {
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  /// Supprime un répertoire et tout son contenu s'il existe.
  static Future<bool> deleteDirectory(String path, {bool recursive = true}) async {
    final Directory dir = Directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: recursive);
      return true;
    }
    return false;
  }

  /// Liste les fichiers d'un répertoire (optionnellement avec une extension).
  static Future<List<File>> listFiles(
    String directoryPath, {
    String? extension,
  }) async {
    final Directory dir = Directory(directoryPath);
    if (!await dir.exists()) {
      return [];
    }
    final List<FileSystemEntity> entities = await dir.list().toList();
    final List<File> files = entities.whereType<File>().toList();

    if (extension != null) {
      return files.where((f) => f.path.endsWith(extension)).toList();
    }
    return files;
  }

  /// Liste les sous-répertoires d'un répertoire.
  static Future<List<Directory>> listDirectories(String directoryPath) async {
    final Directory dir = Directory(directoryPath);
    if (!await dir.exists()) {
      return [];
    }
    final List<FileSystemEntity> entities = await dir.list().toList();
    return entities.whereType<Directory>().toList();
  }

  /// Copie un fichier vers une nouvelle destination.
  static Future<File> copyFile(String sourcePath, String destinationPath, {bool overwrite = true}) async {
    final File source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Fichier source introuvable : $sourcePath');
    }
    final File destination = File(destinationPath);
    if (await destination.exists() && !overwrite) {
      throw FileSystemException('Le fichier de destination existe déjà : $destinationPath');
    }
    final dir = Directory(destination.parent.path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return await source.copy(destinationPath);
  }

  /// Déplace un fichier vers une nouvelle destination.
  static Future<File> moveFile(String sourcePath, String destinationPath, {bool overwrite = true}) async {
    final File source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Fichier source introuvable : $sourcePath');
    }
    final File destination = File(destinationPath);
    if (await destination.exists() && !overwrite) {
      throw FileSystemException('Le fichier de destination existe déjà : $destinationPath');
    }
    final dir = Directory(destination.parent.path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return await source.rename(destinationPath);
  }

  /// Encode un fichier en chaîne base64.
  static Future<String> fileToBase64(String path) async {
    final Uint8List? bytes = await readBinaryFile(path);
    if (bytes == null) {
      throw FileSystemException('Fichier introuvable pour encodage base64 : $path');
    }
    return base64Encode(bytes);
  }

  /// Décode une chaîne base64 et l'écrit dans un fichier binaire.
  static Future<File> base64ToFile(String base64String, String destinationPath) async {
    final Uint8List bytes = base64Decode(base64String);
    return await writeBinaryFile(destinationPath, bytes);
  }

  /// Lit un fichier et le convertit en [Uint8List] pour manipulation mémoire.
  static Future<Uint8List?> readFileAsBytes(String path) async {
    final File file = File(path);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  }

  /// Retourne la taille d'un fichier en octets, ou 0 s'il n'existe pas.
  static Future<int> getFileSize(String path) async {
    final File file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }
}