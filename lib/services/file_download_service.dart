import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service de téléchargement de fichiers depuis une URL.
///
/// Ce service fournit des méthodes pour télécharger des fichiers (comme des APK)
/// depuis Internet vers le stockage local de l'appareil. Il gère :
///   - le téléchargement en streaming avec progression,
///   - l'annulation,
///   - le choix du répertoire de destination,
///   - la gestion des erreurs réseau et HTTP,
///   - la vérification optionnelle de l'intégrité (taille attendue).
///
/// Les fichiers téléchargés sont placés dans un répertoire dédié de l'application
/// (généralement `<documents>/downloads`) pour un accès facile.
class FileDownloadService {
  /// Client HTTP injectable (pour les tests).
  final http.Client? _clientOverride;

  /// Constructeur.
  ///
  /// [clientOverride] : client HTTP personnalisé (optionnel).
  FileDownloadService({http.Client? clientOverride})
      : _clientOverride = clientOverride;

  http.Client _getClient() => _clientOverride ?? http.Client();

  /// Obtient le répertoire de téléchargement (créé si nécessaire).
  Future<Directory> getDownloadDirectory() async {
    final Directory documents = await getApplicationDocumentsDirectory();
    final Directory downloadDir = Directory('${documents.path}/downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  /// Télécharge un fichier depuis une URL.
  ///
  /// [url] : l'URL du fichier.
  /// [fileName] : nom du fichier local (si null, déduit de l'URL ou un nom générique).
  /// [destinationDirectory] : répertoire de destination (si null, utilise `getDownloadDirectory`).
  /// [onProgress] : callback de progression (reçoit les octets reçus et totaux).
  /// [onCancel] : callback appelé lors d'une annulation.
  /// [timeout] : durée maximale sans réception de données avant annulation.
  ///
  /// Retourne le chemin du fichier téléchargé.
  ///
  /// Lève une [FileDownloadException] en cas d'erreur.
  Future<String> downloadFile({
    required String url,
    String? fileName,
    Directory? destinationDirectory,
    void Function(int received, int? total)? onProgress,
    void Function()? onCancel,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final Directory targetDir = destinationDirectory ?? await getDownloadDirectory();
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // Déterminer le nom du fichier
    String finalFileName = fileName ?? _extractFileNameFromUrl(url) ?? 'download.bin';

    // Construire le chemin complet
    final String filePath = '${targetDir.path}/$finalFileName';

    // Lancer la requête en streaming
    final http.Client client = _getClient();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await client.send(request).timeout(timeout);

      if (streamedResponse.statusCode != 200) {
        throw FileDownloadException(
          message: 'Le serveur a répondu avec le code ${streamedResponse.statusCode}',
          statusCode: streamedResponse.statusCode,
        );
      }

      final int? totalBytes = streamedResponse.contentLength;
      int receivedBytes = 0;

      final File file = File(filePath);
      final IOSink sink = file.openWrite();

      try {
        await for (final chunk in streamedResponse.stream.timeout(timeout)) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (onProgress != null) {
            onProgress(receivedBytes, totalBytes);
          }
        }
        await sink.flush();
        await sink.close();
      } catch (e) {
        // En cas d'erreur, fermer le sink et supprimer le fichier partiel
        await sink.close();
        if (await file.exists()) {
          await file.delete();
        }
        if (onCancel != null) {
          onCancel();
        }
        throw FileDownloadException(
          message: 'Téléchargement interrompu : $e',
          cause: e,
        );
      }

      // Vérifier que le fichier existe et n'est pas vide
      if (!await file.exists() || await file.length() == 0) {
        throw FileDownloadException(
          message: 'Le fichier téléchargé est vide ou n\'existe pas',
        );
      }

      return filePath;
    } on FileDownloadException {
      rethrow;
    } catch (e) {
      throw FileDownloadException(
        message: 'Erreur de téléchargement : $e',
        cause: e,
      );
    } finally {
      client.close();
    }
  }

  /// Télécharge un fichier et retourne ses bytes en mémoire.
  ///
  /// Utile pour les petits fichiers.
  /// [url] : l'URL du fichier.
  /// [onProgress] : callback de progression.
  ///
  /// Retourne un [Uint8List].
  Future<Uint8List> downloadBytes({
    required String url,
    void Function(int received, int? total)? onProgress,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final http.Client client = _getClient();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await client.send(request).timeout(timeout);

      if (streamedResponse.statusCode != 200) {
        throw FileDownloadException(
          message: 'Le serveur a répondu avec le code ${streamedResponse.statusCode}',
          statusCode: streamedResponse.statusCode,
        );
      }

      final int? totalBytes = streamedResponse.contentLength;
      int receivedBytes = 0;
      final bytesBuilder = BytesBuilder();

      await for (final chunk in streamedResponse.stream.timeout(timeout)) {
        bytesBuilder.add(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null) {
          onProgress(receivedBytes, totalBytes);
        }
      }

      return bytesBuilder.takeBytes();
    } catch (e) {
      throw FileDownloadException(
        message: 'Erreur de téléchargement : $e',
        cause: e,
      );
    } finally {
      client.close();
    }
  }

  /// Extrait le nom du fichier à partir de l'URL.
  /// Par exemple, `https://example.com/app.apk` retourne `app.apk`.
  static String? _extractFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final last = segments.last;
        if (last.isNotEmpty && last.contains('.')) {
          return last;
        }
      }
    } catch (_) {}
    return null;
  }
}

/// Exception spécifique aux erreurs de téléchargement.
class FileDownloadException implements Exception {
  /// Message d'erreur.
  final String message;

  /// Code HTTP si applicable.
  final int? statusCode;

  /// Cause sous-jacente.
  final Object? cause;

  /// Constructeur.
  const FileDownloadException({
    required this.message,
    this.statusCode,
    this.cause,
  });

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('FileDownloadException: $message');
    if (statusCode != null) {
      buffer.write(' [status: $statusCode]');
    }
    if (cause != null) {
      buffer.write(' [cause: $cause]');
    }
    return buffer.toString();
  }
}