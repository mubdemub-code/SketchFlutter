import '../core/errors/validation_error.dart';
import '../core/utils/json_utils.dart';
import '../core/utils/uuid_generator.dart';

/// Représentation d'un asset (ressource) dans un projet SketchFlutter.
///
/// Un asset peut être une image, une police de caractères, un fichier audio, etc.
/// Il est stocké dans le fichier `.mub` sous forme de données encodées en base64,
/// ce qui permet de le partager avec le projet.
///
/// Chaque asset possède :
///   - un identifiant unique (`id`) pour le référencer dans les widgets (ex: `@assets.logo`).
///   - un nom (`name`) lisible, par exemple "logo.png".
///   - un type (`type`) catégorisant l'asset ([AssetType]).
///   - des données encodées en base64 (`dataBase64`).
///   - un type MIME (`mimeType`) indiquant le format (ex: "image/png").
///   - une taille en octets (`sizeBytes`) pour information.
///
/// La classe est immuable ; utilisez [copyWith] pour créer des copies modifiées.
class AssetModel {
  /// Identifiant unique de l'asset.
  final String id;

  /// Nom lisible de l'asset (ex: "logo.png").
  final String name;

  /// Type de l'asset (image, font, audio, etc.).
  final AssetType type;

  /// Données binaires encodées en base64.
  final String dataBase64;

  /// Type MIME de l'asset (ex: "image/png", "application/font-woff").
  final String mimeType;

  /// Taille en octets (décompressée, si connue).
  final int? sizeBytes;

  /// Constructeur principal.
  const AssetModel({
    required this.id,
    required this.name,
    required this.type,
    required this.dataBase64,
    required this.mimeType,
    this.sizeBytes,
  });

  /// Crée un nouvel asset avec un identifiant généré automatiquement.
  ///
  /// [name] : nom de l'asset.
  /// [type] : type de l'asset.
  /// [dataBase64] : données encodées en base64.
  /// [mimeType] : type MIME.
  /// [sizeBytes] : taille en octets.
  factory AssetModel.create({
    required String name,
    required AssetType type,
    required String dataBase64,
    required String mimeType,
    int? sizeBytes,
  }) {
    if (name.trim().isEmpty) {
      throw ValidationError.missingField('name');
    }
    if (dataBase64.isEmpty) {
      throw ValidationError.missingField('dataBase64');
    }
    return AssetModel(
      id: UuidGenerator.generateAssetId(),
      name: name.trim(),
      type: type,
      dataBase64: dataBase64,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
    );
  }

  /// Crée une instance à partir d'une map JSON.
  ///
  /// [json] : la map contenant les données de l'asset.
  /// Lève une [ValidationError] si des champs obligatoires sont manquants ou invalides.
  factory AssetModel.fromJson(Map<String, dynamic> json) {
    // Identifiant
    final String? id = JsonUtils.getString(json, 'id');
    if (id == null || id.isEmpty) {
      throw ValidationError.missingField('id', path: 'asset');
    }

    // Nom
    final String? name = JsonUtils.getString(json, 'name');
    if (name == null || name.trim().isEmpty) {
      throw ValidationError.missingField('name', path: 'asset.$id');
    }

    // Type
    final String? typeStr = JsonUtils.getString(json, 'type');
    if (typeStr == null) {
      throw ValidationError.missingField('type', path: 'asset.$id');
    }
    final AssetType type = AssetType.fromString(typeStr);

    // Données base64
    final String? dataBase64 = JsonUtils.getString(json, 'data_base64');
    if (dataBase64 == null || dataBase64.isEmpty) {
      throw ValidationError.missingField('data_base64', path: 'asset.$id');
    }

    // Type MIME
    final String? mimeType = JsonUtils.getString(json, 'mime_type');
    if (mimeType == null || mimeType.isEmpty) {
      throw ValidationError.missingField('mime_type', path: 'asset.$id');
    }

    // Taille
    final int? sizeBytes = JsonUtils.getInt(json, 'size_bytes');

    return AssetModel(
      id: id,
      name: name.trim(),
      type: type,
      dataBase64: dataBase64,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
    );
  }

  /// Convertit l'asset en map JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'data_base64': dataBase64,
      'mime_type': mimeType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
    };
  }

  /// Crée une copie de l'asset en remplaçant certains champs.
  AssetModel copyWith({
    String? id,
    String? name,
    AssetType? type,
    String? dataBase64,
    String? mimeType,
    int? sizeBytes,
  }) {
    return AssetModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      dataBase64: dataBase64 ?? this.dataBase64,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  /// Convertit les données base64 en tableau d'octets (Uint8List).
  /// Peut lever une [FormatException] si la chaîne n'est pas du base64 valide.
  Uint8List get bytes => base64Decode(dataBase64);

  @override
  String toString() => 'AssetModel(id: $id, name: $name, type: ${type.name})';
}

/// Enumération des types d'assets supportés.
enum AssetType {
  image,
  font,
  audio,
  video,
  document,
  other;

  /// Convertit une chaîne en [AssetType].
  /// Accepte : "image", "font", "audio", "video", "document", "other".
  /// Par défaut, retourne [AssetType.other] si la chaîne est inconnue.
  static AssetType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'image':
        return AssetType.image;
      case 'font':
        return AssetType.font;
      case 'audio':
        return AssetType.audio;
      case 'video':
        return AssetType.video;
      case 'document':
        return AssetType.document;
      case 'other':
        return AssetType.other;
      default:
        return AssetType.other; // fallback
    }
  }

  /// Convertit le type en chaîne lisible pour l'affichage.
  String get displayName {
    switch (this) {
      case AssetType.image:
        return 'Image';
      case AssetType.font:
        return 'Police';
      case AssetType.audio:
        return 'Audio';
      case AssetType.video:
        return 'Vidéo';
      case AssetType.document:
        return 'Document';
      case AssetType.other:
        return 'Autre';
    }
  }
}