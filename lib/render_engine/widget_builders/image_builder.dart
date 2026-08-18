import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class ImageBuilder {
  static Widget build(WidgetNode node, RenderContext context) {
    final props = node.properties ?? {};
    final src = context.resolver.resolveVariableValue(props['src'])?.toString();
    final width = _parseDouble(props['width']);
    final height = _parseDouble(props['height']);
    final fit = _parseBoxFit(props['fit']);

    if (src == null) {
      return Container(
        color: Colors.grey.shade300,
        width: width ?? 100,
        height: height ?? 100,
        child: const Icon(Icons.image, color: Colors.grey),
      );
    }

    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(src, width: width, height: height, fit: fit);
    }
    // Asset local
    return Image.asset(src, width: width, height: height, fit: fit);
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static BoxFit? _parseBoxFit(dynamic value) {
    switch (value?.toString()) {
      case 'cover': return BoxFit.cover;
      case 'contain': return BoxFit.contain;
      case 'fill': return BoxFit.fill;
      case 'scaleDown': return BoxFit.scaleDown;
      default: return null;
    }
  }
}