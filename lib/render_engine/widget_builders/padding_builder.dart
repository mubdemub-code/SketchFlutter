import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class PaddingBuilder {
  static Widget build(WidgetNode node, Widget? child, RenderContext context) {
    final props = node.properties ?? {};
    final padding = context.edgeInsetsParser.parse(props['padding']) ?? EdgeInsets.zero;
    return Padding(padding: padding, child: child);
  }
}