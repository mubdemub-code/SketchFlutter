import '../models/logic_block.dart';
import '../models/page_model.dart';
import '../models/project_model.dart';
import '../models/widget_node.dart';
import '../models/variable.dart';
import 'logic_code_generators/code_block_generator.dart';
import 'widget_code_generators/widget_code_utils.dart';
import 'widget_code_generators/container_generator.dart';
import 'widget_code_generators/text_generator.dart';
import 'widget_code_generators/row_column_generator.dart';
import 'widget_code_generators/button_generator.dart';
import 'widget_code_generators/image_generator.dart';
import 'widget_code_generators/icon_generator.dart';
import 'widget_code_generators/textfield_generator.dart';
import 'widget_code_generators/checkbox_generator.dart';
import 'widget_code_generators/switch_generator.dart';
import 'widget_code_generators/slider_generator.dart';
import 'widget_code_generators/listview_generator.dart';
import 'widget_code_generators/gridview_generator.dart';
import 'widget_code_generators/listtile_generator.dart';
import 'widget_code_generators/appbar_generator.dart';
import 'widget_code_generators/sizedbox_generator.dart';
import 'widget_code_generators/padding_generator.dart';
import 'widget_code_generators/center_generator.dart';

/// Générateur de code Dart complet, gérant l'état, les événements et la navigation.
///
/// Cette version produit un code Flutter autonome qui utilise un singleton
/// `AppState` pour les variables globales et des pages réactives.
class ProjectToDart {
  /// Génère le fichier `lib/app_state.dart`.
  static String generateAppState(ProjectModel project) {
    final buffer = StringBuffer();

    buffer.writeln("import 'package:flutter/foundation.dart';");
    buffer.writeln();
    buffer.writeln('/// État global de l\'application générée.');
    buffer.writeln('class AppState extends ChangeNotifier {');
    buffer.writeln('  AppState._();');
    buffer.writeln('  static final AppState instance = AppState._();');
    buffer.writeln();
    for (final variable in project.variables) {
      final typeName = _dartTypeForVariable(variable.type);
      final initialValue = _literalToCode(variable.initialValue, variable.type);
      buffer.writeln('  $typeName _${variable.id} = $initialValue;');
    }
    buffer.writeln();
    for (final variable in project.variables) {
      final typeName = _dartTypeForVariable(variable.type);
      buffer.writeln('  $typeName get ${variable.id} => _${variable.id};');
    }
    buffer.writeln();
    for (final variable in project.variables) {
      final typeName = _dartTypeForVariable(variable.type);
      buffer.writeln('  void set_${variable.id}($typeName value) {');
      buffer.writeln('    _${variable.id} = value;');
      buffer.writeln('    notifyListeners();');
      buffer.writeln('  }');
      buffer.writeln();
    }
    buffer.writeln('}');
    return buffer.toString();
  }

  /// Génère le fichier `lib/main.dart`.
  static String generateMain(ProjectModel project) {
    final buffer = StringBuffer();

    buffer.writeln("import 'package:flutter/material.dart';");
    buffer.writeln("import 'app_state.dart';");
    for (final page in project.pages) {
      final pageFileName = _toSnakeCase(page.name);
      buffer.writeln("import 'pages/${pageFileName}_page.dart';");
    }
    if (project.customCode.dartImports != null &&
        project.customCode.dartImports!.isNotEmpty) {
      buffer.writeln(project.customCode.dartImports);
    }
    buffer.writeln();

    if (project.customCode.initCode != null &&
        project.customCode.initCode!.isNotEmpty) {
      buffer.writeln('void _init() {');
      buffer.writeln(project.customCode.initCode!);
      buffer.writeln('}');
      buffer.writeln();
    }
    if (project.customCode.globalFunctions != null &&
        project.customCode.globalFunctions!.isNotEmpty) {
      buffer.writeln(project.customCode.globalFunctions);
      buffer.writeln();
    }
    if (project.customCode.additionalClasses != null &&
        project.customCode.additionalClasses!.isNotEmpty) {
      buffer.writeln(project.customCode.additionalClasses);
      buffer.writeln();
    }

    buffer.writeln('void main() {');
    buffer.writeln('  WidgetsFlutterBinding.ensureInitialized();');
    if (project.customCode.initCode != null &&
        project.customCode.initCode!.isNotEmpty) {
      buffer.writeln('  _init();');
    }
    buffer.writeln('  runApp(const MyApp());');
    buffer.writeln('}');
    buffer.writeln();

    buffer.writeln('class MyApp extends StatelessWidget {');
    buffer.writeln('  const MyApp({super.key});');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  Widget build(BuildContext context) {');
    buffer.writeln('    return MaterialApp(');
    buffer.writeln('      title: ${_escapeString(project.metadata.name)},');
    buffer.writeln('      theme: ThemeData(');
    buffer.writeln('        colorScheme: ColorScheme.fromSeed(seedColor: ${WidgetCodeUtils.colorToCode(project, project.designSystem.colors['primary'] ?? '#FF6200EE')}),');
    buffer.writeln('        useMaterial3: true,');
    buffer.writeln('      ),');
    final initialPage = project.getPageById(project.navigation.initialPageId);
    if (initialPage != null) {
      buffer.writeln('      home: ${_pageClassName(initialPage.name)}(),');
    } else {
      buffer.writeln('      home: const Scaffold(body: Center(child: Text(\'Aucune page\'))),');
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln('}');
    return buffer.toString();
  }

  /// Génère le fichier d'une page.
  static String generatePage(ProjectModel project, PageModel page) {
    final buffer = StringBuffer();

    buffer.writeln("import 'package:flutter/material.dart';");
    buffer.writeln("import '../app_state.dart';");
    for (final otherPage in project.pages) {
      if (otherPage.id != page.id) {
        buffer.writeln("import '${_toSnakeCase(otherPage.name)}_page.dart';");
      }
    }
    buffer.writeln();

    buffer.writeln('class ${_pageClassName(page.name)} extends StatefulWidget {');
    buffer.writeln('  const ${_pageClassName(page.name)}({super.key});');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  State<${_pageClassName(page.name)}> createState() => _${_pageClassName(page.name)}State();');
    buffer.writeln('}');
    buffer.writeln();

    buffer.writeln('class _${_pageClassName(page.name)}State extends State<${_pageClassName(page.name)}> {');
    buffer.writeln('  @override');
    buffer.writeln('  Widget build(BuildContext context) {');
    buffer.writeln('    return ListenableBuilder(');
    buffer.writeln('      listenable: AppState.instance,');
    buffer.writeln('      builder: (context, _) {');
    buffer.writeln('        return ${_widgetToCode(project, page.rootWidget, 4)};');
    buffer.writeln('      },');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Convertit un `WidgetNode` en code Dart.
  static String _widgetToCode(ProjectModel project, WidgetNode node, int indentLevel) {
    final indent = '  ' * indentLevel;
    final type = node.type;
    final child = node.child;
    final children = node.children;

    switch (type) {
      case 'Scaffold':
        return _scaffoldToCode(project, node, indent, indentLevel);
      case 'Container':
        final childCode = child != null ? _widgetToCode(project, child, indentLevel + 1) : null;
        return ContainerGenerator.generate(project, node, childCode, indent);
      case 'Text':
        return TextGenerator.generate(project, node, indent);
      case 'Row':
      case 'Column':
        final childrenCodes = children?.map((c) => _widgetToCode(project, c, indentLevel + 1)).toList() ?? [];
        return RowColumnGenerator.generate(project, node, childrenCodes, indent);
      case 'Button':
      case 'ElevatedButton':
      case 'TextButton':
      case 'OutlinedButton':
        final childCode = child != null ? _widgetToCode(project, child, indentLevel + 2) : '';
        final eventBlocks = _getEventBlocks(project, node.id, 'onPressed');
        final onPressedCode = eventBlocks.isNotEmpty
            ? _generateEventCallback(project, eventBlocks, indent + '  ')
            : '() {}';
        return ButtonGenerator.generate(project, node, childCode, onPressedCode, indent);
      case 'Image':
        return ImageGenerator.generate(project, node, indent);
      case 'Icon':
        return IconGenerator.generate(project, node, indent);
      case 'TextField':
        final eventBlocks = _getEventBlocks(project, node.id, 'onChanged');
        final onChangedCode = eventBlocks.isNotEmpty
            ? _generateEventCallback(project, eventBlocks, indent + '  ')
            : '(value) {}';
        return TextFieldGenerator.generate(project, node, onChangedCode, indent);
      case 'Checkbox':
        final eventBlocks = _getEventBlocks(project, node.id, 'onChanged');
        final onChangedCode = eventBlocks.isNotEmpty
            ? _generateEventCallback(project, eventBlocks, indent + '  ')
            : '(value) {}';
        return CheckboxGenerator.generate(project, node, onChangedCode, indent);
      case 'Switch':
        final eventBlocks = _getEventBlocks(project, node.id, 'onChanged');
        final onChangedCode = eventBlocks.isNotEmpty
            ? _generateEventCallback(project, eventBlocks, indent + '  ')
            : '(value) {}';
        return SwitchGenerator.generate(project, node, onChangedCode, indent);
      case 'Slider':
        final eventBlocks = _getEventBlocks(project, node.id, 'onChanged');
        final onChangedCode = eventBlocks.isNotEmpty
            ? _generateEventCallback(project, eventBlocks, indent + '  ')
            : '(value) {}';
        return SliderGenerator.generate(project, node, onChangedCode, indent);
      case 'ListView':
        final childrenCodes = children?.map((c) => _widgetToCode(project, c, indentLevel + 1)).toList() ?? [];
        return ListViewGenerator.generate(project, node, childrenCodes, indent);
      case 'GridView':
        final childrenCodes = children?.map((c) => _widgetToCode(project, c, indentLevel + 1)).toList() ?? [];
        return GridViewGenerator.generate(project, node, childrenCodes, indent);
      case 'ListTile':
        final eventBlocks = _getEventBlocks(project, node.id, 'onTap');
        final onTapCode = eventBlocks.isNotEmpty
            ? _generateEventCallback(project, eventBlocks, indent + '  ')
            : '() {}';
        return ListTileGenerator.generate(project, node, onTapCode, indent);
      case 'AppBar':
        return AppBarGenerator.generate(project, node, indent);
      case 'SizedBox':
        final childCode = child != null ? _widgetToCode(project, child, indentLevel + 1) : null;
        return SizedBoxGenerator.generate(project, node, childCode, indent);
      case 'Padding':
        final childCode = child != null ? _widgetToCode(project, child, indentLevel + 1) : null;
        return PaddingGenerator.generate(project, node, childCode, indent);
      case 'Center':
        final childCode = child != null ? _widgetToCode(project, child, indentLevel + 1) : null;
        return CenterGenerator.generate(project, node, childCode, indent);
      default:
        return 'Container()';
    }
  }

  /// Génère le code d'un Scaffold (conservé ici car il gère la recherche d'enfants spécifiques).
  static String _scaffoldToCode(ProjectModel project, WidgetNode node, String indent, int indentLevel) {
    final props = node.properties ?? {};
    final appBarNode = _findChildByType(node, 'AppBar');
    final bodyNode = _findChildNotType(node, 'AppBar');
    final backgroundColor = props['backgroundColor'];
    final buffer = StringBuffer('Scaffold(\n');
    if (backgroundColor != null) {
      buffer.writeln('$indent  backgroundColor: ${WidgetCodeUtils.colorToCode(project, backgroundColor)},');
    }
    buffer.writeln('$indent  appBar: ${appBarNode != null ? _widgetToCode(project, appBarNode, indentLevel + 1) : 'null'},');
    buffer.writeln('$indent  body: ${bodyNode != null ? _widgetToCode(project, bodyNode, indentLevel + 1) : 'null'},');
    buffer.write('$indent)');
    return buffer.toString();
  }

  /// Récupère les blocs associés à un événement.
  static List<LogicBlock> _getEventBlocks(ProjectModel project, String widgetId, String eventName) {
    for (final page in project.pages) {
      final bindings = page.logicBindings;
      if (bindings != null && bindings.containsKey(widgetId)) {
        final events = bindings[widgetId]!;
        if (events.containsKey(eventName)) {
          return events[eventName]!.map((json) => LogicBlock.fromJson(json)).toList();
        }
      }
    }
    return [];
  }

  /// Génère une fonction callback à partir des blocs.
  static String _generateEventCallback(ProjectModel project, List<LogicBlock> blocks, String indent) {
    final buffer = StringBuffer('() {\n');
    for (final block in blocks) {
      buffer.writeln(CodeBlockGenerator.generate(block, indent: indent + '  '));
    }
    buffer.write('$indent}');
    return buffer.toString();
  }

  /// Convertit une valeur littérale en code Dart.
  static String _literalToCode(dynamic value, VariableType? type) {
    if (value == null) return 'null';
    if (value is bool) return value ? 'true' : 'false';
    if (value is num) return value.toString();
    if (value is String) {
      return _escapeString(value);
    }
    return value.toString();
  }

  /// Trouve un enfant par type (pour Scaffold).
  static WidgetNode? _findChildByType(WidgetNode node, String type) {
    if (node.child?.type == type) return node.child;
    if (node.children != null) {
      for (final child in node.children!) {
        if (child.type == type) return child;
      }
    }
    return null;
  }

  static WidgetNode? _findChildNotType(WidgetNode node, String type) {
    if (node.child?.type != type) return node.child;
    if (node.children != null) {
      for (final child in node.children!) {
        if (child.type != type) return child;
      }
    }
    return null;
  }

  // --- Helpers de nommage ---
  static String _pageClassName(String pageName) => '${_toPascalCase(pageName)}Page';

  static String _toSnakeCase(String input) => input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  static String _toPascalCase(String input) => input
      .split(RegExp(r'[^a-zA-Z0-9]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join();

  static String _dartTypeForVariable(VariableType type) {
    switch (type) {
      case VariableType.int: return 'int';
      case VariableType.double: return 'double';
      case VariableType.bool: return 'bool';
      case VariableType.string: return 'String';
      case VariableType.list: return 'List<dynamic>';
      case VariableType.map: return 'Map<String, dynamic>';
      case VariableType.object: return 'dynamic';
      default: return 'dynamic';
    }
  }

  static String _escapeString(String str) => "'${str.replaceAll("'", "\\'")}'";
}