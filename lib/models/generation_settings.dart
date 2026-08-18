import '../core/errors/validation_error.dart';
import '../core/utils/json_utils.dart';

/// Paramètres de génération de l'APK pour un projet SketchFlutter.
///
/// Ces paramètres sont utilisés lors de l'export/compilation pour configurer
/// l'application Android générée. Ils sont stockés dans le JSON du projet
/// sous la clé `generation_settings`.
///
/// Champs principaux :
///   - [packageName] : nom du package Android (ex: `com.monapp.app`).
///   - [version] : version de l'application (ex: `1.0.0`).
///   - [applicationName] : nom affiché de l'application (par défaut le nom du projet).
///   - [androidPermissions] : liste des permissions Android requises.
///   - [orientation] : orientation de l'écran autorisée.
///   - [iconAssetId] : identifiant de l'asset à utiliser comme icône.
///   - [minSdkVersion] : version minimale du SDK Android.
///   - [targetSdkVersion] : version cible du SDK Android.
///
/// La classe est immuable ; utilisez [copyWith] pour créer des copies modifiées.
class GenerationSettings {
  /// Nom du package Android (ex: `com.monapp.app`).
  final String packageName;

  /// Version de l'application (ex: `1.0.0`).
  final String version;

  /// Nom affiché de l'application (peut différer du nom du projet).
  final String? applicationName;

  /// Liste des permissions Android (ex: `INTERNET`, `CAMERA`).
  final List<String> androidPermissions;

  /// Orientation de l'écran autorisée.
  final AppOrientation orientation;

  /// Identifiant de l'asset à utiliser comme icône de l'application.
  /// Si null, l'icône par défaut de Flutter sera utilisée.
  final String? iconAssetId;

  /// Version minimale du SDK Android (défaut 21, correspondant à Android 5.0).
  final int minSdkVersion;

  /// Version cible du SDK Android (défaut 34).
  final int targetSdkVersion;

  /// Constructeur principal.
  const GenerationSettings({
    required this.packageName,
    required this.version,
    this.applicationName,
    this.androidPermissions = const [],
    this.orientation = AppOrientation.portrait,
    this.iconAssetId,
    this.minSdkVersion = 21,
    this.targetSdkVersion = 34,
  });

  /// Crée une instance avec des valeurs par défaut pour un nouveau projet.
  ///
  /// [packageName] : nom de package unique (obligatoire).
  /// [version] : version (défaut "1.0.0").
  factory GenerationSettings.create({
    required String packageName,
    String version = '1.0.0',
  }) {
    if (packageName.trim().isEmpty) {
      throw ValidationError.missingField('packageName');
    }
    return GenerationSettings(
      packageName: packageName.trim(),
      version: version.trim().isEmpty ? '1.0.0' : version.trim(),
    );
  }

  /// Crée une instance à partir d'une map JSON.
  ///
  /// [json] : la map contenant les paramètres.
  /// Les champs `package_name` et `version` sont obligatoires.
  /// Les autres champs sont optionnels avec des valeurs par défaut.
  ///
  /// Lève une [ValidationError] en cas de champ manquant ou invalide.
  factory GenerationSettings.fromJson(Map<String, dynamic> json) {
    // Nom de package
    final String? packageName = JsonUtils.getString(json, 'package_name');
    if (packageName == null || packageName.trim().isEmpty) {
      throw ValidationError.missingField('package_name', path: 'generation_settings');
    }

    // Version
    final String? version = JsonUtils.getString(json, 'version');
    if (version == null || version.trim().isEmpty) {
      throw ValidationError.missingField('version', path: 'generation_settings');
    }

    // Nom de l'application (optionnel)
    final String? applicationName = JsonUtils.getString(json, 'application_name');

    // Permissions Android
    List<String> androidPermissions = [];
    if (json.containsKey('android_permissions')) {
      final dynamic permsData = json['android_permissions'];
      if (permsData is List) {
        androidPermissions = permsData
            .where((e) => e is String)
            .map((e) => e as String)
            .toList();
      } else if (permsData != null) {
        throw ValidationError.invalidType(
          'android_permissions',
          'List<String>',
          '${permsData.runtimeType}',
          path: 'generation_settings.android_permissions',
        );
      }
    }

    // Orientation
    AppOrientation orientation = AppOrientation.portrait;
    if (json.containsKey('orientation')) {
      final String? orientationStr = JsonUtils.getString(json, 'orientation');
      if (orientationStr != null) {
        orientation = AppOrientation.fromString(orientationStr);
      }
    }

    // Icône
    final String? iconAssetId = JsonUtils.getString(json, 'icon_asset_id');

    // Versions SDK
    final int minSdk = JsonUtils.getInt(json, 'min_sdk_version') ?? 21;
    final int targetSdk = JsonUtils.getInt(json, 'target_sdk_version') ?? 34;

    return GenerationSettings(
      packageName: packageName.trim(),
      version: version.trim(),
      applicationName: applicationName,
      androidPermissions: androidPermissions,
      orientation: orientation,
      iconAssetId: iconAssetId,
      minSdkVersion: minSdk,
      targetSdkVersion: targetSdk,
    );
  }

  /// Convertit l'objet en map JSON.
  Map<String, dynamic> toJson() {
    return {
      'package_name': packageName,
      'version': version,
      if (applicationName != null) 'application_name': applicationName,
      if (androidPermissions.isNotEmpty) 'android_permissions': androidPermissions,
      'orientation': orientation.name,
      if (iconAssetId != null) 'icon_asset_id': iconAssetId,
      'min_sdk_version': minSdkVersion,
      'target_sdk_version': targetSdkVersion,
    };
  }

  /// Crée une copie en remplaçant certains champs.
  GenerationSettings copyWith({
    String? packageName,
    String? version,
    String? applicationName,
    List<String>? androidPermissions,
    AppOrientation? orientation,
    String? iconAssetId,
    int? minSdkVersion,
    int? targetSdkVersion,
  }) {
    return GenerationSettings(
      packageName: packageName ?? this.packageName,
      version: version ?? this.version,
      applicationName: applicationName ?? this.applicationName,
      androidPermissions: androidPermissions ?? this.androidPermissions,
      orientation: orientation ?? this.orientation,
      iconAssetId: iconAssetId ?? this.iconAssetId,
      minSdkVersion: minSdkVersion ?? this.minSdkVersion,
      targetSdkVersion: targetSdkVersion ?? this.targetSdkVersion,
    );
  }

  /// Retourne une copie profonde.
  GenerationSettings deepCopy() {
    return GenerationSettings(
      packageName: packageName,
      version: version,
      applicationName: applicationName,
      androidPermissions: List<String>.from(androidPermissions),
      orientation: orientation,
      iconAssetId: iconAssetId,
      minSdkVersion: minSdkVersion,
      targetSdkVersion: targetSdkVersion,
    );
  }

  /// Vérifie si les paramètres sont valides.
  ///
  /// Critères : `packageName` non vide, `version` non vide,
  /// `minSdkVersion` <= `targetSdkVersion`.
  bool isValid() {
    return packageName.trim().isNotEmpty &&
        version.trim().isNotEmpty &&
        minSdkVersion <= targetSdkVersion;
  }

  @override
  String toString() =>
      'GenerationSettings(package: $packageName, version: $version, orientation: ${orientation.name})';
}

/// Enumération des orientations d'écran autorisées.
enum AppOrientation {
  /// Orientation portrait uniquement.
  portrait,

  /// Orientation paysage uniquement.
  landscape,

  /// Les deux orientations sont autorisées.
  both;

  /// Convertit une chaîne en [AppOrientation].
  /// Accepte : "portrait", "landscape", "both".
  /// Par défaut, retourne [AppOrientation.portrait].
  static AppOrientation fromString(String value) {
    switch (value.toLowerCase()) {
      case 'portrait':
        return AppOrientation.portrait;
      case 'landscape':
        return AppOrientation.landscape;
      case 'both':
        return AppOrientation.both;
      default:
        return AppOrientation.portrait;
    }
  }

  /// Convertit l'orientation en chaîne lisible pour l'affichage.
  String get displayName {
    switch (this) {
      case AppOrientation.portrait:
        return 'Portrait';
      case AppOrientation.landscape:
        return 'Paysage';
      case AppOrientation.both:
        return 'Les deux';
    }
  }
}