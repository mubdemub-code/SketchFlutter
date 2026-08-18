import '../../models/project_model.dart';
import '../../models/widget_node.dart';
import 'widget_code_utils.dart';

class ContainerGenerator {
  static String generate(ProjectModel project, WidgetNode node, String? childCode, String indent) {
    final props = node.properties ?? {};
    final color = props['color'];
    final width = props['width'];
    final height = props['height'];
    final padding = props['padding'];
    final margin = props['margin'];
    final alignment = props['alignment'];
    final borderRadius = props['borderRadius'];

    final buffer = StringBuffer('Container(\n');
    if (width != null) buffer.writeln('$indent  width: ${WidgetCodeUtils.doubleToCode(width)},');
    if (height != null) buffer.writeln('$indent  height: ${WidgetCodeUtils.doubleToCode(height)},');
    if (padding != null) buffer.writeln('$indent  padding: ${WidgetCodeUtils.edgeInsetsToCode(padding)},');
    if (margin != null) buffer.writeln('$indent  margin: ${WidgetCodeUtils.edgeInsetsToCode(margin)},');
    if (color != null) buffer.writeln('$indent  color: ${WidgetCodeUtils.colorToCode(project, color)},');
    if (alignment != null) buffer.writeln('$indent  alignment: ${WidgetCodeUtils.alignmentToCode(alignment)},');
    if (borderRadius != null) {
      buffer.writeln('$indent  decoration: BoxDecoration(');
      buffer.writeln('$indent    borderRadius: BorderRadius.circular(${WidgetCodeUtils.doubleToCode(borderRadius)}),');
      buffer.writeln('$indent  ),');
    }
    buffer.writeln('$indent  child: ${childCode ?? 'null'},');
    buffer.write('$indent)');
    return buffer.toString();
  }
}