import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class CenterBuilder {
  static Widget build(WidgetNode node, Widget? child, RenderContext context) {
    return Center(child: child);
  }
}