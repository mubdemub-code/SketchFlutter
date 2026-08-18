import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class ScaffoldBuilder {
  static Widget build(WidgetNode node, Widget? appBar, Widget? body, RenderContext context) {
    final props = node.properties ?? {};
    final backgroundColor = context.colorParser.parse(props['backgroundColor']);
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar as PreferredSizeWidget?,
      body: body,
    );
  }
}