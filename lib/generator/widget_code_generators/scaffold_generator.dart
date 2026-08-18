import '../../models/project_model.dart';
import '../../models/widget_node.dart';
import 'widget_code_utils.dart';

class ScaffoldGenerator {
  static String generate(ProjectModel project, WidgetNode node, String indent, int indentLevel) {
    final props = node.properties ?? {};
    final appBarNode = _findChildByType(node, 'AppBar');
    final bodyNode = _findChildNotType(node, 'AppBar');
    final backgroundColor = props['backgroundColor'];
    final buffer = StringBuffer('Scaffold(\n');
    if (backgroundColor != null) {
      buffer.writeln('$indent  backgroundColor: ${WidgetCodeUtils.colorToCode(project, backgroundColor)},');
    }
    buffer.writeln('$indent  appBar: ${appBarNode != null ? generate(project, appBarNode, indent + '  ', indentLevel + 1) : 'null'},');
    buffer.writeln('$indent  body: ${bodyNode != null ? generate(project, bodyNode, indent + '  ', indentLevel + 1) : 'null'},');
    buffer.write('$indent)');
    return buffer.toString();
  }

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
}