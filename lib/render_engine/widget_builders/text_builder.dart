import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class TextBuilder {
  static Widget build(WidgetNode node, RenderContext context) {
    final props = node.properties ?? {};
    final rawData = props['data'];
    final data = context.resolver.resolveVariableValue(rawData)?.toString() ?? '';
    final style = context.textStyleParser.parse(props['style']);
    final textAlign = _parseTextAlign(props['textAlign']);
    final maxLines = props['maxLines'] as int?;
    final overflow = _parseTextOverflow(props['overflow']);

    return Text(
      data,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  static TextAlign? _parseTextAlign(dynamic value) {
    switch (value?.toString()) {
      case 'left': return TextAlign.left;
      case 'right': return TextAlign.right;
      case 'center': return TextAlign.center;
      case 'justify': return TextAlign.justify;
      default: return null;
    }
  }

  static TextOverflow? _parseTextOverflow(dynamic value) {
    switch (value?.toString()) {
      case 'ellipsis': return TextOverflow.ellipsis;
      case 'fade': return TextOverflow.fade;
      case 'clip': return TextOverflow.clip;
      default: return null;
    }
  }
}