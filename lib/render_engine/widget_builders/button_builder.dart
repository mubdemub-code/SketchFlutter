import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class ButtonBuilder {
  static Widget build(WidgetNode node, Widget? child, VoidCallback? onPressed, RenderContext context) {
    final props = node.properties ?? {};
    final text = props['text']?.toString() ?? props['data']?.toString() ?? 'Bouton';
    final buttonType = props['buttonType']?.toString() ?? 'elevated';
    final color = context.colorParser.parse(props['color']) ?? Colors.blue;
    final textColor = context.colorParser.parse(props['textColor']) ?? Colors.white;
    final finalChild = child ?? Text(text);

    switch (buttonType) {
      case 'text':
        return TextButton(onPressed: onPressed ?? () {}, child: finalChild);
      case 'outlined':
        return OutlinedButton(onPressed: onPressed ?? () {}, child: finalChild);
      default:
        return ElevatedButton(
          onPressed: onPressed ?? () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: textColor,
          ),
          child: finalChild,
        );
    }
  }
}