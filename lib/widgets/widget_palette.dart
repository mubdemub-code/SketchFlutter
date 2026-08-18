import 'package:flutter/material.dart';

/// Représente un élément de la palette de widgets.
class WidgetPaletteItem {
  /// Type de widget (ex: "Container", "Text", etc.).
  final String type;

  /// Libellé affiché sous l'icône.
  final String label;

  /// Icône représentant le widget.
  final IconData icon;

  const WidgetPaletteItem({
    required this.type,
    required this.label,
    required this.icon,
  });
}

/// Palette horizontale de widgets pour l'éditeur.
///
/// Affiche une liste défilante de widgets avec icône et libellé.
/// Chaque élément peut être sélectionné (tap) pour déclencher un callback.
/// Utilisé principalement dans l'onglet Design de l'éditeur.
class WidgetPalette extends StatelessWidget {
  /// Callback appelé lorsqu'un widget est sélectionné.
  /// Reçoit le type du widget (ex: "Container").
  final ValueChanged<String> onWidgetSelected;

  /// Liste des éléments à afficher.
  final List<WidgetPaletteItem> items;

  const WidgetPalette({
    super.key,
    required this.onWidgetSelected,
    this.items = defaultItems,
  });

  /// Liste par défaut des widgets les plus courants.
  static const List<WidgetPaletteItem> defaultItems = [
    WidgetPaletteItem(
      type: 'Container',
      label: 'Conteneur',
      icon: Icons.crop_square,
    ),
    WidgetPaletteItem(
      type: 'Text',
      label: 'Texte',
      icon: Icons.text_fields,
    ),
    WidgetPaletteItem(
      type: 'Row',
      label: 'Ligne',
      icon: Icons.view_column,
    ),
    WidgetPaletteItem(
      type: 'Column',
      label: 'Colonne',
      icon: Icons.view_agenda,
    ),
    WidgetPaletteItem(
      type: 'Button',
      label: 'Bouton',
      icon: Icons.smart_button,
    ),
    WidgetPaletteItem(
      type: 'Image',
      label: 'Image',
      icon: Icons.image_outlined,
    ),
    WidgetPaletteItem(
      type: 'Icon',
      label: 'Icône',
      icon: Icons.emoji_emotions_outlined,
    ),
    WidgetPaletteItem(
      type: 'TextField',
      label: 'Champ',
      icon: Icons.input,
    ),
    WidgetPaletteItem(
      type: 'Checkbox',
      label: 'Case',
      icon: Icons.check_box_outlined,
    ),
    WidgetPaletteItem(
      type: 'Switch',
      label: 'Interrupteur',
      icon: Icons.toggle_on_outlined,
    ),
    WidgetPaletteItem(
      type: 'Slider',
      label: 'Curseur',
      icon: Icons.linear_scale,
    ),
    WidgetPaletteItem(
      type: 'ListView',
      label: 'Liste',
      icon: Icons.list,
    ),
    WidgetPaletteItem(
      type: 'GridView',
      label: 'Grille',
      icon: Icons.grid_view,
    ),
    WidgetPaletteItem(
      type: 'ListTile',
      label: 'Tuile',
      icon: Icons.view_list,
    ),
    WidgetPaletteItem(
      type: 'Scaffold',
      label: 'Écran',
      icon: Icons.smartphone,
    ),
    WidgetPaletteItem(
      type: 'AppBar',
      label: 'Barre',
      icon: Icons.vertical_align_top,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final iconColor = isDark ? Colors.white : Colors.black54;

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _PaletteButton(
            item: item,
            iconColor: iconColor,
            textColor: textColor,
            onTap: () => onWidgetSelected(item.type),
          );
        },
      ),
    );
  }
}

/// Bouton individuel de la palette.
class _PaletteButton extends StatelessWidget {
  final WidgetPaletteItem item;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;

  const _PaletteButton({
    required this.item,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 64,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 28, color: iconColor),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}