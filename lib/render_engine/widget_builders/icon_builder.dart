import 'package:flutter/material.dart';

import '../../models/widget_node.dart';
import '../render_context.dart';

class IconBuilder {
  static Widget build(WidgetNode node, RenderContext context) {
    final props = node.properties ?? {};
    final iconName = props['icon']?.toString() ?? 'circle';
    final color = context.colorParser.parse(props['color']) ?? Colors.black;
    final size = _parseDouble(props['size']) ?? 24;
    final iconData = _iconDataFromName(iconName);

    return Icon(iconData, color: color, size: size);
  }

  static IconData _iconDataFromName(String name) {
    const map = {
      'home': Icons.home,
      'favorite': Icons.favorite,
      'star': Icons.star,
      'person': Icons.person,
      'settings': Icons.settings,
      'search': Icons.search,
      'add': Icons.add,
      'delete': Icons.delete,
      'edit': Icons.edit,
      'check': Icons.check,
      'close': Icons.close,
      'menu': Icons.menu,
      'share': Icons.share,
      'download': Icons.download,
      'upload': Icons.upload,
      'refresh': Icons.refresh,
      'info': Icons.info,
      'warning': Icons.warning,
      'error': Icons.error,
      'help': Icons.help,
      'notifications': Icons.notifications,
      'email': Icons.email,
      'phone': Icons.phone,
      'camera': Icons.camera,
      'image': Icons.image,
    };
    return map[name] ?? Icons.circle;
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}