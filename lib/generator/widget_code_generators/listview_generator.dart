import '../../models/project_model.dart';
import '../../models/widget_node.dart';
import 'widget_code_utils.dart';

class ListViewGenerator {
  static String generate(ProjectModel project, WidgetNode node, List<String> childrenCodes, String indent) {
    final props = node.properties ?? {};
    final scrollDirection = props['scrollDirection'] ?? 'vertical';
    final reverse = props['reverse'] ?? false;

    final buffer = StringBuffer('ListView(\n');
    buffer.writeln('$indent  scrollDirection: ${scrollDirection == 'horizontal' ? 'Axis.horizontal' : 'Axis.vertical'},');
    if (reverse == true) buffer.writeln('$indent  reverse: true,');
    if (childrenCodes.isNotEmpty) {
      buffer.writeln('$indent  children: [');
      for (final code in childrenCodes) {
        buffer.writeln('$indent    $code,');
      }
      buffer.writeln('$indent  ],');
    }
    buffer.write('$indent)');
    return buffer.toString();
  }
}