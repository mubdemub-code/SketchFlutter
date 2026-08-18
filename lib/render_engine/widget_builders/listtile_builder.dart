import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class ListTileBuilder {
  static Widget build(WidgetNode node, RenderContext context, {VoidCallback? onTap}) {
    final props = node.properties ?? {};
    final title = props['title']?.toString() ?? '';
    final subtitle = props['subtitle']?.toString();
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      onTap: onTap ?? () {},
    );
  }
}