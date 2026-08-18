import '../../models/project_model.dart';
import '../../models/widget_node.dart';
import 'widget_code_utils.dart';

class AppBarGenerator {
  static String generate(ProjectModel project, WidgetNode node, String indent) {
    final props = node.properties ?? {};
    final title = props['title'] ?? '';
    final backgroundColor = props['backgroundColor'];

    final buffer = StringBuffer('AppBar(\n');
    buffer.writeln('$indent  title: Text(${WidgetCodeUtils.escapeString(title)}),');
    if (backgroundColor != null) buffer.writeln('$indent  backgroundColor: ${WidgetCodeUtils.colorToCode(project, backgroundColor)},');
    buffer.write('$indent)');
    return buffer.toString();
  }
}