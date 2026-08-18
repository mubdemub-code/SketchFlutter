import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class SliderBuilder {
  static Widget build(WidgetNode node, RenderContext context, {ValueChanged<double>? onChanged}) {
    final props = node.properties ?? {};
    final min = _parseDouble(props['min']) ?? 0;
    final max = _parseDouble(props['max']) ?? 100;
    final rawValue = props['value'];
    final value = context.resolver.resolveVariableValue(rawValue) as double? ?? min;
    return Slider(value: value, min: min, max: max, onChanged: onChanged ?? (v) {});
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}