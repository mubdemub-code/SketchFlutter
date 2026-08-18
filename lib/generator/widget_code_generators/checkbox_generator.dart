import '../../models/project_model.dart';
import '../../models/widget_node.dart';
import 'widget_code_utils.dart';

class CheckboxGenerator {
  static String generate(ProjectModel project, WidgetNode node, String? onChangedCode, String indent) {
    final props = node.properties ?? {};
    final value = props['value'];
    final valueStr = WidgetCodeUtils.resolveVariableValue(project, value);
    return 'Checkbox(\n$indent  value: $valueStr,\n$indent  onChanged: ${onChangedCode ?? '(value) {}'},\n$indent)';
  }
}