import '../../models/project_model.dart';
import '../../models/widget_node.dart';
import 'widget_code_utils.dart';

class TextFieldGenerator {
  static String generate(ProjectModel project, WidgetNode node, String? onChangedCode, String indent) {
    final props = node.properties ?? {};
    final hintText = props['hintText'];
    final obscureText = props['obscureText'] ?? false;
    final keyboardType = props['keyboardType'];
    final maxLines = props['maxLines'];
    final controllerCode = _controllerCode(project, node);

    final buffer = StringBuffer('TextField(\n');
    if (hintText != null) buffer.writeln('$indent  decoration: InputDecoration(hintText: ${WidgetCodeUtils.escapeString(hintText)}),');
    if (obscureText == true) buffer.writeln('$indent  obscureText: true,');
    if (keyboardType != null) buffer.writeln('$indent  keyboardType: ${WidgetCodeUtils.keyboardTypeToCode(keyboardType)},');
    if (maxLines != null) buffer.writeln('$indent  maxLines: $maxLines,');
    if (controllerCode != null) buffer.writeln('$indent  controller: $controllerCode,');
    buffer.writeln('$indent  onChanged: ${onChangedCode ?? '(value) {}'},');
    buffer.write('$indent)');
    return buffer.toString();
  }

  static String? _controllerCode(ProjectModel project, WidgetNode node) {
    final props = node.properties ?? {};
    final controller = props['controller'];
    if (controller != null && controller is String && controller.startsWith('@variables.')) {
      final varId = controller.substring('@variables.'.length);
      return "TextEditingController(text: AppState.instance.$varId.toString())..addListener(() { AppState.instance.set_$varId(controller.text); })";
    }
    return null;
  }
}