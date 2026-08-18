import '../../models/project_model.dart';
import '../../models/widget_node.dart';
import 'widget_code_utils.dart';

class ImageGenerator {
  static String generate(ProjectModel project, WidgetNode node, String indent) {
    final props = node.properties ?? {};
    final src = props['src'];
    final width = props['width'];
    final height = props['height'];
    final fit = props['fit'];

    if (src == null) {
      return 'Placeholder(fallbackHeight: 100, fallbackWidth: 100)';
    }
    final srcStr = WidgetCodeUtils.resolveVariableValue(project, src);
    final isNetwork = srcStr.startsWith('http://') || srcStr.startsWith('https://');
    final imageCode = isNetwork
        ? 'Image.network($srcStr)'
        : 'Image.asset($srcStr)';

    if (width != null || height != null || fit != null) {
      final buffer = StringBuffer('Image.network(\n$indent  $srcStr,\n');
      if (width != null) buffer.writeln('$indent  width: ${WidgetCodeUtils.doubleToCode(width)},');
      if (height != null) buffer.writeln('$indent  height: ${WidgetCodeUtils.doubleToCode(height)},');
      if (fit != null) buffer.writeln('$indent  fit: ${WidgetCodeUtils.boxFitToCode(fit)},');
      buffer.write('$indent)');
      return buffer.toString();
    }
    return imageCode;
  }
}