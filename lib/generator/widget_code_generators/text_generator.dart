import '../../models/project_model.dart';
import '../../models/widget_node.dart';
import 'widget_code_utils.dart';

class TextGenerator {
  static String generate(ProjectModel project, WidgetNode node, String indent) {
    final props = node.properties ?? {};
    final data = props['data'];
    final style = props['style'];
    final textAlign = props['textAlign'];
    final maxLines = props['maxLines'];
    final overflow = props['overflow'];

    final buffer = StringBuffer('Text(\n');
    final dataStr = WidgetCodeUtils.resolveVariableValue(project, data);
    buffer.writeln('$indent  $dataStr,');
    if (style != null) {
      buffer.writeln('$indent  style: ${WidgetCodeUtils.textStyleToCode(project, style)},');
    }
    if (textAlign != null) buffer.writeln('$indent  textAlign: ${WidgetCodeUtils.textAlignToCode(textAlign)},');
    if (maxLines != null) buffer.writeln('$indent  maxLines: $maxLines,');
    if (overflow != null) buffer.writeln('$indent  overflow: ${WidgetCodeUtils.textOverflowToCode(overflow)},');
    buffer.write('$indent)');
    return buffer.toString();
  }
}