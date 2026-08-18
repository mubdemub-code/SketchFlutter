import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class SwitchBuilder {
  static Widget build(WidgetNode node, RenderContext context, {ValueChanged<bool>? onChanged}) {
    final props = node.properties ?? {};
    final rawValue = props['value'];
    final value = context.resolver.resolveVariableValue(rawValue) as bool? ?? false;
    return Switch(value: value, onChanged: onChanged ?? (v) {});
  }
}