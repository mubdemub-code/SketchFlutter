import 'package:flutter/material.dart';

import '../models/project_model.dart';
import '../models/widget_node.dart';
import 'render_context.dart';
import 'widget_builders/scaffold_builder.dart';
import 'widget_builders/container_builder.dart';
import 'widget_builders/text_builder.dart';
import 'widget_builders/row_column_builder.dart';
import 'widget_builders/button_builder.dart';
import 'widget_builders/image_builder.dart';
import 'widget_builders/icon_builder.dart';
import 'widget_builders/textfield_builder.dart';
import 'widget_builders/checkbox_builder.dart';
import 'widget_builders/switch_builder.dart';
import 'widget_builders/slider_builder.dart';
import 'widget_builders/listview_builder.dart';
import 'widget_builders/grid_view_builder.dart';
import 'widget_builders/list_tile_builder.dart';
import 'widget_builders/app_bar_builder.dart';
import 'widget_builders/sizedbox_builder.dart';
import 'widget_builders/padding_builder.dart';
import 'widget_builders/center_builder.dart';

  // importer tous les builders

/// Parser principal JSON → Widget Flutter.
///
/// Utilise un [RenderContext] pour résoudre les références et convertir les
/// propriétés. La récursion est gérée ici : pour chaque nœud, on extrait les
/// enfants, on les construit, puis on appelle le builder approprié.
///
/// Les événements sont délégués à une fonction [onEvent] fournie, qui prend
/// en paramètre l'ID du widget et le nom de l'événement. C'est au
/// [LogicExecutor] de fournir cette fonction.
class JsonWidgetParser {
  final RenderContext context;
  final void Function(String widgetId, String eventName)? onEvent;

  JsonWidgetParser({
    required this.context,
    this.onEvent,
  });

  /// Construit le widget correspondant au nœud.
  Widget build(WidgetNode node) {
    final type = node.type;
    final childNode = node.child;
    final childrenNodes = node.children;

    // Construire les enfants
    Widget? childWidget;
    if (childNode != null) {
      childWidget = build(childNode);
    }
    List<Widget> childrenWidgets = [];
    if (childrenNodes != null) {
      childrenWidgets = childrenNodes.map((child) => build(child)).toList();
    }

    switch (type) {
      case 'Scaffold':
        // Rechercher AppBar et body
        Widget? appBar;
        Widget? body;
        for (final child in childrenWidgets) {
          if (child is PreferredSizeWidget) {
            appBar = child;
          } else if (body == null) {
            body = child;
          }
        }
        // ou utiliser les nœuds enfants pour identifier par type
        // On va plutôt se baser sur les nœuds.
        final appBarNode = _findChildByType(node, 'AppBar');
        final bodyNode = _findChildNotType(node, 'AppBar');
        return ScaffoldBuilder.build(
          node,
          appBarNode != null ? build(appBarNode) : null,
          bodyNode != null ? build(bodyNode) : null,
          context,
        );

      case 'Container':
        return ContainerBuilder.build(node, childWidget, context);

      case 'Text':
        return TextBuilder.build(node, context);

      case 'Row':
      case 'Column':
        return RowColumnBuilder.build(node, childrenWidgets, context);

      case 'Button':
      case 'ElevatedButton':
      case 'TextButton':
      case 'OutlinedButton':
        return ButtonBuilder.build(
          node,
          childWidget,
          () => _triggerEvent(node, 'onPressed'),
          context,
        );

      case 'Image':
        return ImageBuilder.build(node, context);

      case 'Icon':
        return IconBuilder.build(node, context);

      case 'TextField':
        return TextFieldBuilder.build(
          node,
          context,
          onChanged: (value) => _triggerEvent(node, 'onChanged'),
        );

      case 'Checkbox':
        return CheckboxBuilder.build(
          node,
          context,
          onChanged: (value) => _triggerEvent(node, 'onChanged'),
        );

      case 'Switch':
        return SwitchBuilder.build(
          node,
          context,
          onChanged: (value) => _triggerEvent(node, 'onChanged'),
        );

      case 'Slider':
        return SliderBuilder.build(
          node,
          context,
          onChanged: (value) => _triggerEvent(node, 'onChanged'),
        );

      case 'ListView':
        return ListViewBuilder.build(node, childrenWidgets, context);

      case 'GridView':
        return GridViewBuilder.build(node, childrenWidgets, context);

      case 'ListTile':
        return ListTileBuilder.build(
          node,
          context,
          onTap: () => _triggerEvent(node, 'onTap'),
        );

      case 'AppBar':
        return AppBarBuilder.build(node, context);

      case 'SizedBox':
        return SizedBoxBuilder.build(node, childWidget, context);

      case 'Padding':
        return PaddingBuilder.build(node, childWidget, context);

      case 'Center':
        return CenterBuilder.build(node, childWidget, context);

      default:
        return Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey.shade200,
          child: Text('Widget inconnu: $type'),
        );
    }
  }

  /// Déclenche un événement si un callback est défini.
  void _triggerEvent(WidgetNode node, String eventName) {
    if (onEvent != null) {
      onEvent!(node.id, eventName);
    }
  }

  /// Trouve un enfant par type.
  WidgetNode? _findChildByType(WidgetNode node, String type) {
    if (node.child?.type == type) return node.child;
    if (node.children != null) {
      for (final child in node.children!) {
        if (child.type == type) return child;
      }
    }
    return null;
  }

  WidgetNode? _findChildNotType(WidgetNode node, String type) {
    if (node.child?.type != type) return node.child;
    if (node.children != null) {
      for (final child in node.children!) {
        if (child.type != type) return child;
      }
    }
    return null;
  }
}