import '../../models/project_model.dart';
import '../../models/widget_node.dart';
import 'widget_code_utils.dart';

class ButtonGenerator {
  static String generate(ProjectModel project, WidgetNode node, String childCode, String? onPressedCode, String indent) {
    final props = node.properties ?? {};
    final text = props['text'] ?? props['data'] ?? 'Bouton';
    final buttonType = props['buttonType'] ?? 'elevated';
    final color = props['color'];
    final textColor = props['textColor'];

    final finalChild = childCode.isNotEmpty ? childCode : 'Text(${WidgetCodeUtils.escapeString(text)})';
    final onPressed = onPressedCode ?? '() {}';

    switch (buttonType) {
      case 'text':
        return 'TextButton(\n$indent  onPressed: $onPressed,\n$indent  child: $finalChild,\n$indent)';
      case 'outlined':
        return 'OutlinedButton(\n$indent  onPressed: $onPressed,\n$indent  child: $finalChild,\n$indent)';
      default:
        final colorStr = color != null ? WidgetCodeUtils.colorToCode(project, color) : 'Colors.blue';
        final textColorStr = textColor != null ? WidgetCodeUtils.colorToCode(project, textColor) : 'Colors.white';
        return 'ElevatedButton(\n'
            '$indent  onPressed: $onPressed,\n'
            '$indent  style: ElevatedButton.styleFrom(\n'
            '$indent    backgroundColor: $colorStr,\n'
            '$indent    foregroundColor: $textColorStr,\n'
            '$indent  ),\n'
            '$indent  child: $finalChild,\n'
            '$indent)';
    }
  }
}