import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class GridViewBuilder {
  static Widget build(WidgetNode node, List<Widget> children, RenderContext context) {
    final props = node.properties ?? {};
    final crossAxisCount = props['crossAxisCount'] as int? ?? 2;
    return GridView.count(
      crossAxisCount: crossAxisCount,
      children: children,
    );
  }
}