import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class AppBarBuilder {
  static PreferredSizeWidget build(WidgetNode node, RenderContext context) {
    final props = node.properties ?? {};
    final title = props['title']?.toString() ?? '';
    final backgroundColor = context.colorParser.parse(props['backgroundColor']);
    return AppBar(
      title: Text(title),
      backgroundColor: backgroundColor,
    );
  }
}