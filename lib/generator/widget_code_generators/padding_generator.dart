import '../../models/project_model.dart';
import '../../models/widget_node.dart';
import 'widget_code_utils.dart';

class PaddingGenerator {
  static String generate(ProjectModel project, WidgetNode node, String? childCode, String indent) {
    final props = node.properties ?? {};
    final padding = props['padding'];

    return 'Padding(\n$indent  padding: ${WidgetCodeUtils.edgeInsetsToCode(padding)},\n$indent  child: ${childCode ?? 'null'},\n$indent)';
  }
}