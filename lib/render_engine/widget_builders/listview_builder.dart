import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class ListViewBuilder {
  static Widget build(WidgetNode node, List<Widget> children, RenderContext context) {
    final props = node.properties ?? {};
    final scrollDirection = props['scrollDirection'] == 'horizontal' ? Axis.horizontal : Axis.vertical;
    final reverse = props['reverse'] as bool? ?? false;
    final padding = context.edgeInsetsParser.parse(props['padding']) ?? EdgeInsets.zero;
    return ListView(
      scrollDirection: scrollDirection,
      reverse: reverse,
      padding: padding,
      children: children,
    );
  }
}