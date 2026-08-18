import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class RowColumnBuilder {
  static Widget build(WidgetNode node, List<Widget> children, RenderContext context) {
    final isRow = node.type == 'Row';
    final props = node.properties ?? {};
    final mainAxisAlignment = _parseMainAxisAlignment(props['mainAxisAlignment']);
    final crossAxisAlignment = _parseCrossAxisAlignment(props['crossAxisAlignment']);
    final mainAxisSize = props['mainAxisSize'] == 'min' ? MainAxisSize.min : MainAxisSize.max;

    if (isRow) {
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: children,
      );
    } else {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: children,
      );
    }
  }

  static MainAxisAlignment _parseMainAxisAlignment(dynamic value) {
    switch (value?.toString()) {
      case 'center': return MainAxisAlignment.center;
      case 'end': return MainAxisAlignment.end;
      case 'spaceBetween': return MainAxisAlignment.spaceBetween;
      case 'spaceAround': return MainAxisAlignment.spaceAround;
      case 'spaceEvenly': return MainAxisAlignment.spaceEvenly;
      default: return MainAxisAlignment.start;
    }
  }

  static CrossAxisAlignment _parseCrossAxisAlignment(dynamic value) {
    switch (value?.toString()) {
      case 'center': return CrossAxisAlignment.center;
      case 'end': return CrossAxisAlignment.end;
      case 'stretch': return CrossAxisAlignment.stretch;
      default: return CrossAxisAlignment.start;
    }
  }
}