import 'dart:math';

/// Générateur d'identifiants uniques.
///
/// Cette classe produit des identifiants courts et lisibles, adaptés aux besoins
/// de l'éditeur (widgets, pages, variables, assets, blocs logiques, etc.).
/// Les identifiants sont aléatoires mais avec une probabilité de collision négligeable.
class UuidGenerator {
  static final Random _random = Random.secure();

  /// Caractères utilisés pour générer les identifiants.
  /// Exclut les caractères ambigus (0, O, 1, l, I) pour éviter les confusions.
  static const String _alphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';

  /// Longueur par défaut des identifiants.
  static const int _defaultLength = 12;

  /// Génère un identifiant unique simple.
  ///
  /// [prefix] : préfixe optionnel pour catégoriser l'identifiant (ex: "widget_", "page_", "var_").
  /// [length] : longueur de la partie aléatoire (défaut 12).
  ///
  /// Exemples :
  ///   `UuidGenerator.generate()`               → "aB3kLmNpQrSt"
  ///   `UuidGenerator.generate(prefix: "w_")`   → "w_aB3kLmNpQrSt"
  static String generate({String prefix = '', int length = _defaultLength}) {
    if (length <= 0) {
      throw ArgumentError('La longueur doit être supérieure à zéro');
    }
    final StringBuffer buffer = StringBuffer(prefix);
    for (int i = 0; i < length; i++) {
      final int index = _random.nextInt(_alphabet.length);
      buffer.write(_alphabet[index]);
    }
    return buffer.toString();
  }

  /// Génère un identifiant unique pour un widget.
  static String generateWidgetId() => generate(prefix: 'widget_');

  /// Génère un identifiant unique pour une page.
  static String generatePageId() => generate(prefix: 'page_');

  /// Génère un identifiant unique pour une variable.
  static String generateVariableId() => generate(prefix: 'var_');

  /// Génère un identifiant unique pour un asset.
  static String generateAssetId() => generate(prefix: 'asset_');

  /// Génère un identifiant unique pour un bloc logique.
  static String generateBlockId() => generate(prefix: 'block_');

  /// Génère un identifiant unique pour un projet.
  static String generateProjectId() => generate(prefix: 'proj_');

  /// Génère un identifiant unique basé sur le temps (triable chronologiquement).
  ///
  /// Utile pour les métadonnées ou les sauvegardes horodatées.
  /// Format : `prefix + timestamp base36 + random`
  static String generateTimeBased({String prefix = '', int randomLength = 6}) {
    final int timestamp = DateTime.now().microsecondsSinceEpoch;
    final String timestampBase36 = timestamp.toRadixString(36);
    final String randomPart = generate(length: randomLength);
    return '$prefix$timestampBase36$randomPart';
  }

  /// Génère un UUID v4 standard (format 8-4-4-4-12).
  ///
  /// Utile si un identifiant globalement unique est requis (ex: synchronisation cloud).
  static String generateUuidV4() {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 36; i++) {
      if (i == 8 || i == 13 || i == 18 || i == 23) {
        buffer.write('-');
      } else if (i == 14) {
        buffer.write('4'); // version 4
      } else if (i == 19) {
        buffer.write('8'); // variant standard
      } else {
        final int index = _random.nextInt(16);
        buffer.write(index.toRadixString(16));
      }
    }
    return buffer.toString();
  }

  /// Génère une liste de [count] identifiants uniques.
  static List<String> generateBatch(int count, {String prefix = '', int length = _defaultLength}) {
    if (count <= 0) {
      throw ArgumentError('Le nombre d\'identifiants doit être supérieur à zéro');
    }
    final List<String> ids = [];
    final Set<String> seen = {};
    while (ids.length < count) {
      final String id = generate(prefix: prefix, length: length);
      if (!seen.contains(id)) {
        seen.add(id);
        ids.add(id);
      }
    }
    return ids;
  }
}