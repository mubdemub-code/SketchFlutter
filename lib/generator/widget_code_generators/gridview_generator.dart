import '../../models/project_model.dart';
import '../../models/widget_node.dart';
import 'widget_code_utils.dart';

class GridViewGenerator {
  static String generate(ProjectModel project, WidgetNode node, List<String> childrenCodes, String indent) {
    final props = node.properties ?? {};
    final crossAxisCount = props['crossAxisCount'] ?? 2;

    final buffer = StringBuffer('GridView.count(\n');
    buffer.writeln('$indent  crossAxisCount: $crossAxisCount,');
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