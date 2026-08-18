import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class SizedBoxBuilder {
  static Widget build(WidgetNode node, Widget? child, RenderContext context) {
    final props = node.properties ?? {};
    final width = _parseDouble(props['width']);
    final height = _parseDouble(props['height']);
    return SizedBox(width: width, height: height, child: child);
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}