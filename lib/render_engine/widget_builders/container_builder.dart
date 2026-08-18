import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class ContainerBuilder {
  static Widget build(WidgetNode node, Widget? child, RenderContext context) {
    final props = node.properties ?? {};
    final color = context.colorParser.parse(props['color']);
    final width = _parseDouble(props['width']);
    final height = _parseDouble(props['height']);
    final padding = context.edgeInsetsParser.parse(props['padding']);
    final margin = context.edgeInsetsParser.parse(props['margin']);
    final alignment = context.alignmentParser.parse(props['alignment']);
    final borderRadius = _parseDouble(props['borderRadius']);

    return Container(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius != null ? BorderRadius.circular(borderRadius) : null,
      ),
      child: child,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}