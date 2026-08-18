import '../../models/project_model.dart';

/// Classe utilitaire pour la génération de code des widgets.
///
/// Fournit des méthodes statiques de conversion (couleurs, EdgeInsets, etc.)
/// utilisées par les générateurs de widgets.
class WidgetCodeUtils {
  /// Convertit une valeur en code couleur Dart.
  static String colorToCode(ProjectModel project, dynamic value) {
    if (value == null) return 'Colors.transparent';
    if (value is String && value.startsWith('@colors.')) {
      final name = value.substring('@colors.'.length);
      final hex = project.designSystem.colors[name];
      if (hex != null) return _colorToHex(hex);
    }
    if (value is String) return _colorToHex(value);
    return 'Colors.transparent';
  }

  static String _colorToHex(String hex) {
    String cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) cleaned = 'FF$cleaned';
    return 'Color(0x$cleaned)';
  }

  /// Convertit une valeur en code EdgeInsets.
  static String edgeInsetsToCode(dynamic value) {
    if (value == null) return 'EdgeInsets.zero';
    if (value is Map) {
      if (value.containsKey('all')) return 'EdgeInsets.all(${value['all']})';
      final top = value['top'] ?? 0;
      final bottom = value['bottom'] ?? 0;
      final left = value['left'] ?? 0;
      final right = value['right'] ?? 0;
      return 'EdgeInsets.only(top: $top, bottom: $bottom, left: $left, right: $right)';
    }
    if (value is num) return 'EdgeInsets.all($value)';
    return 'EdgeInsets.zero';
  }

  /// Convertit une valeur en code Alignment.
  static String alignmentToCode(dynamic value) {
    switch (value?.toString()) {
      case 'center': return 'Alignment.center';
      case 'topLeft': return 'Alignment.topLeft';
      case 'topCenter': return 'Alignment.topCenter';
      case 'topRight': return 'Alignment.topRight';
      case 'centerLeft': return 'Alignment.centerLeft';
      case 'centerRight': return 'Alignment.centerRight';
      case 'bottomLeft': return 'Alignment.bottomLeft';
      case 'bottomCenter': return 'Alignment.bottomCenter';
      case 'bottomRight': return 'Alignment.bottomRight';
      default: return 'Alignment.center';
    }
  }

  /// Convertit une valeur en code MainAxisAlignment.
  static String mainAxisAlignmentToCode(dynamic value) {
    switch (value?.toString()) {
      case 'center': return 'MainAxisAlignment.center';
      case 'end': return 'MainAxisAlignment.end';
      case 'spaceBetween': return 'MainAxisAlignment.spaceBetween';
      case 'spaceAround': return 'MainAxisAlignment.spaceAround';
      case 'spaceEvenly': return 'MainAxisAlignment.spaceEvenly';
      default: return 'MainAxisAlignment.start';
    }
  }

  /// Convertit une valeur en code CrossAxisAlignment.
  static String crossAxisAlignmentToCode(dynamic value) {
    switch (value?.toString()) {
      case 'center': return 'CrossAxisAlignment.center';
      case 'end': return 'CrossAxisAlignment.end';
      case 'stretch': return 'CrossAxisAlignment.stretch';
      default: return 'CrossAxisAlignment.start';
    }
  }

  /// Convertit une valeur en code MainAxisSize.
  static String mainAxisSizeToCode(dynamic value) {
    return value?.toString() == 'min' ? 'MainAxisSize.min' : 'MainAxisSize.max';
  }

  /// Convertit une valeur en code TextAlign.
  static String textAlignToCode(dynamic value) {
    switch (value?.toString()) {
      case 'left': return 'TextAlign.left';
      case 'right': return 'TextAlign.right';
      case 'center': return 'TextAlign.center';
      case 'justify': return 'TextAlign.justify';
      default: return 'TextAlign.left';
    }
  }

  /// Convertit une valeur en code TextOverflow.
  static String textOverflowToCode(dynamic value) {
    switch (value?.toString()) {
      case 'ellipsis': return 'TextOverflow.ellipsis';
      case 'fade': return 'TextOverflow.fade';
      case 'clip': return 'TextOverflow.clip';
      default: return 'TextOverflow.clip';
    }
  }

  /// Convertit une valeur en code BoxFit.
  static String boxFitToCode(dynamic value) {
    switch (value?.toString()) {
      case 'cover': return 'BoxFit.cover';
      case 'contain': return 'BoxFit.contain';
      case 'fill': return 'BoxFit.fill';
      case 'scaleDown': return 'BoxFit.scaleDown';
      default: return 'BoxFit.contain';
    }
  }

  /// Convertit une valeur en code TextInputType.
  static String keyboardTypeToCode(dynamic value) {
    switch (value?.toString()) {
      case 'number': return 'TextInputType.number';
      case 'email': return 'TextInputType.emailAddress';
      case 'phone': return 'TextInputType.phone';
      default: return 'TextInputType.text';
    }
  }

  /// Convertit un nom d'icône en code IconData.
  static String iconNameToCode(dynamic name) {
    final map = {
      'home': 'Icons.home',
      'favorite': 'Icons.favorite',
      'star': 'Icons.star',
      'person': 'Icons.person',
      'settings': 'Icons.settings',
      'search': 'Icons.search',
      'add': 'Icons.add',
      'delete': 'Icons.delete',
      'edit': 'Icons.edit',
      'check': 'Icons.check',
      'close': 'Icons.close',
      'menu': 'Icons.menu',
      'share': 'Icons.share',
      'download': 'Icons.download',
      'upload': 'Icons.upload',
      'refresh': 'Icons.refresh',
      'info': 'Icons.info',
      'warning': 'Icons.warning',
      'error': 'Icons.error',
      'help': 'Icons.help',
      'notifications': 'Icons.notifications',
      'email': 'Icons.email',
      'phone': 'Icons.phone',
      'camera': 'Icons.camera',
      'image': 'Icons.image',
    };
    return map[name] ?? 'Icons.circle';
  }

  /// Convertit une valeur en code double.
  static String doubleToCode(dynamic value) {
    final d = _parseDoubleOrNull(value);
    return d != null ? d.toString() : 'null';
  }

  static double? _parseDoubleOrNull(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Échappe une chaîne pour l'inclure dans du code Dart.
  static String escapeString(String str) {
    return "'${str.replaceAll("'", "\\'")}'";
  }

  /// Convertit une valeur en code TextStyle.
  static String textStyleToCode(ProjectModel project, dynamic style) {
    if (style == null) return 'const TextStyle()';
    if (style is String && style.startsWith('@text_styles.')) {
      final name = style.substring('@text_styles.'.length);
      final styleMap = project.designSystem.textStyles[name];
      if (styleMap == null) return 'const TextStyle()';
      return _textStyleMapToCode(project, styleMap);
    }
    if (style is Map<String, dynamic>) {
      return _textStyleMapToCode(project, style);
    }
    return 'const TextStyle()';
  }

  static String _textStyleMapToCode(ProjectModel project, Map<String, dynamic> map) {
    final buffer = StringBuffer('TextStyle(');
    if (map['fontSize'] != null) buffer.write('fontSize: ${map['fontSize']}, ');
    if (map['fontWeight'] != null) buffer.write('fontWeight: ${_fontWeightToCode(map['fontWeight'])}, ');
    if (map['color'] != null) buffer.write('color: ${colorToCode(project, map['color'])}, ');
    if (map['fontStyle'] != null) buffer.write('fontStyle: ${map['fontStyle'] == 'italic' ? 'FontStyle.italic' : 'FontStyle.normal'}, ');
    buffer.write(')');
    return buffer.toString();
  }

  static String _fontWeightToCode(dynamic weight) {
    if (weight is int) {
      return 'FontWeight.w$weight';
    }
    switch (weight?.toString()) {
      case 'bold': return 'FontWeight.bold';
      case 'normal': return 'FontWeight.normal';
      default: return 'FontWeight.w400';
    }
  }

  /// Résout une valeur de variable (pour les Text, etc.)
  static String resolveVariableValue(ProjectModel project, dynamic value) {
    if (value is String && value.startsWith('@variables.')) {
      final varId = value.substring('@variables.'.length);
      return "AppState.instance.$varId.toString()";
    }
    return _literalToCode(value);
  }

  static String _literalToCode(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return value ? 'true' : 'false';
    if (value is num) return value.toString();
    if (value is String) return escapeString(value);
    return value.toString();
  }
}