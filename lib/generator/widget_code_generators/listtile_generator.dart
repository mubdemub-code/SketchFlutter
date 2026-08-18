import '../../models/project_model.dart';
import '../../models/widget_node.dart';
import 'widget_code_utils.dart';

class ListTileGenerator {
  static String generate(ProjectModel project, WidgetNode node, String? onTapCode, String indent) {
    final props = node.properties ?? {};
    final title = props['title'];
    final subtitle = props['subtitle'];

    final buffer = StringBuffer('ListTile(\n');
    if (title != null) buffer.writeln('$indent  title: Text(${WidgetCodeUtils.escapeString(title)}),');
    if (subtitle != null) buffer.writeln('$indent  subtitle: Text(${WidgetCodeUtils.escapeString(subtitle)}),');
    buffer.writeln('$indent  onTap: ${onTapCode ?? '() {}'},');
    buffer.write('$indent)');
    return buffer.toString();
  }
}