import '../../models/project_model.dart';
import '../../models/widget_node.dart';

class CenterGenerator {
  static String generate(ProjectModel project, WidgetNode node, String? childCode, String indent) {
    return 'Center(\n$indent  child: ${childCode ?? 'null'},\n$indent)';
  }
}