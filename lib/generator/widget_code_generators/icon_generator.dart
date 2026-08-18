import '../../models/project_model.dart';
import '../../models/widget_node.dart';
import 'widget_code_utils.dart';

class IconGenerator {
  static String generate(ProjectModel project, WidgetNode node, String indent) {
    final props = node.properties ?? {};
    final iconName = props['icon'] ?? 'circle';
    final color = props['color'];
    final size = props['size'];

    final iconData = WidgetCodeUtils.iconNameToCode(iconName);
    final buffer = StringBuffer('Icon(\n');
    buffer.writeln('$indent  $iconData,');
    if (color != null) buffer.writeln('$indent  color: ${WidgetCodeUtils.colorToCode(project, color)},');
    if (size != null) buffer.writeln('$indent  size: ${WidgetCodeUtils.doubleToCode(size)},');
    buffer.write('$indent)');
    return buffer.toString();
  }
}