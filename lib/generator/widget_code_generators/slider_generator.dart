import '../../models/project_model.dart';
import '../../models/widget_node.dart';
import 'widget_code_utils.dart';

class SliderGenerator {
  static String generate(ProjectModel project, WidgetNode node, String? onChangedCode, String indent) {
    final props = node.properties ?? {};
    final min = props['min'] ?? 0;
    final max = props['max'] ?? 100;
    final value = props['value'];
    final valueStr = WidgetCodeUtils.resolveVariableValue(project, value);
    return 'Slider(\n$indent  value: $valueStr,\n$indent  min: $min,\n$indent  max: $max,\n$indent  onChanged: ${onChangedCode ?? '(value) {}'},\n$indent)';
  }
}