import '../../models/project_model.dart';
import '../../models/widget_node.dart';
import 'widget_code_utils.dart';

class SizedBoxGenerator {
  static String generate(ProjectModel project, WidgetNode node, String? childCode, String indent) {
    final props = node.properties ?? {};
    final width = props['width'];
    final height = props['height'];

    return 'SizedBox(\n$indent  width: ${WidgetCodeUtils.doubleToCode(width)},\n$indent  height: ${WidgetCodeUtils.doubleToCode(height)},\n$indent  child: ${childCode ?? 'null'},\n$indent)';
  }
}