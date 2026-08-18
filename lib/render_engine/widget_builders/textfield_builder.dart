import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class TextFieldBuilder {
  static Widget build(WidgetNode node, RenderContext context, {ValueChanged<String>? onChanged}) {
    final props = node.properties ?? {};
    final hintText = props['hintText']?.toString();
    final obscureText = props['obscureText'] as bool? ?? false;
    final keyboardType = _parseKeyboardType(props['keyboardType']);
    final maxLines = props['maxLines'] as int? ?? 1;

    return TextField(
      decoration: InputDecoration(hintText: hintText),
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged ?? (value) {},
    );
  }

  static TextInputType _parseKeyboardType(dynamic value) {
    switch (value?.toString()) {
      case 'number': return TextInputType.number;
      case 'email': return TextInputType.emailAddress;
      case 'phone': return TextInputType.phone;
      default: return TextInputType.text;
    }
  }
}