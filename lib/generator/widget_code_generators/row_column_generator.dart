import '../../models/project_model.dart';
import '../../models/widget_node.dart';
import 'widget_code_utils.dart';

class RowColumnGenerator {
  static String generate(ProjectModel project, WidgetNode node, List<String> childrenCodes, String indent) {
    final isRow = node.type == 'Row';
    final props = node.properties ?? {};
    final mainAxisAlignment = props['mainAxisAlignment'];
    final crossAxisAlignment = props['crossAxisAlignment'];
    final mainAxisSize = props['mainAxisSize'];

    final buffer = StringBuffer('${isRow ? 'Row' : 'Column'}(\n');
    if (mainAxisAlignment != null) buffer.writeln('$indent  mainAxisAlignment: ${WidgetCodeUtils.mainAxisAlignmentToCode(mainAxisAlignment)},');
    if (crossAxisAlignment != null) buffer.writeln('$indent  crossAxisAlignment: ${WidgetCodeUtils.crossAxisAlignmentToCode(crossAxisAlignment)},');
    if (mainAxisSize != null) buffer.writeln('$indent  mainAxisSize: ${WidgetCodeUtils.mainAxisSizeToCode(mainAxisSize)},');
    if (childrenCodes.isNotEmpty) {
      buffer.writeln('$indent  children: [');
      for (final code in childrenCodes) {
        buffer.writeln('$indent    $code,');
      }
      buffer.writeln('$indent  ],');
    } else {
      buffer.writeln('$indent  children: const [],');
    }
    buffer.write('$indent)');
    return buffer.toString();
  }
}