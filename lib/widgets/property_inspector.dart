import 'package:flutter/material.dart';

import '../models/widget_node.dart';
import 'color_picker.dart';
import 'dropdown_input.dart';
import 'icon_picker.dart';
import 'number_input.dart';

/// Types de contrôles disponibles pour l'édition des propriétés.
enum PropertyControlType {
  text,
  multilineText,
  number,
  color,
  dropdown,
  icon,
  boolean,
}

/// Configuration d'un champ de propriété.
class PropertyFieldConfig {
  /// Clé de la propriété dans le JSON (ex: "color", "fontSize").
  final String key;

  /// Libellé affiché.
  final String label;

  /// Type de contrôle à utiliser.
  final PropertyControlType controlType;

  /// Options pour les dropdowns (liste de valeurs).
  final List<dynamic>? options;

  /// Fonction de formatage pour les labels des dropdowns.
  final String? Function(dynamic)? optionLabel;

  /// Autoriser la valeur nulle (pour number, dropdown).
  final bool allowNull;

  /// Valeur minimale (pour number).
  final double? min;

  /// Valeur maximale (pour number).
  final double? max;

  /// Autoriser les décimales (pour number).
  final bool allowDecimal;

  /// Suffixe (pour number).
  final String? suffix;

  /// Afficher un slider (pour number).
  final bool showSlider;

  /// Valeur par défaut si la propriété est absente.
  final dynamic defaultValue;

  const PropertyFieldConfig({
    required this.key,
    required this.label,
    required this.controlType,
    this.options,
    this.optionLabel,
    this.allowNull = false,
    this.min,
    this.max,
    this.allowDecimal = true,
    this.suffix,
    this.showSlider = false,
    this.defaultValue,
  });
}

/// Configuration des champs de propriétés pour chaque type de widget.
/// Ce mapping est utilisé par [PropertyInspector] pour générer dynamiquement
/// les contrôles d'édition.
const Map<String, List<PropertyFieldConfig>> _widgetPropertyFields = {
  'Container': [
    PropertyFieldConfig(
      key: 'color',
      label: 'Couleur de fond',
      controlType: PropertyControlType.color,
      defaultValue: '#FFFFFFFF',
    ),
    PropertyFieldConfig(
      key: 'width',
      label: 'Largeur',
      controlType: PropertyControlType.number,
      allowNull: true,
      min: 0,
      suffix: 'dp',
    ),
    PropertyFieldConfig(
      key: 'height',
      label: 'Hauteur',
      controlType: PropertyControlType.number,
      allowNull: true,
      min: 0,
      suffix: 'dp',
    ),
    PropertyFieldConfig(
      key: 'padding',
      label: 'Padding',
      controlType: PropertyControlType.text,
      allowNull: true,
    ),
    PropertyFieldConfig(
      key: 'margin',
      label: 'Marge',
      controlType: PropertyControlType.text,
      allowNull: true,
    ),
    PropertyFieldConfig(
      key: 'alignment',
      label: 'Alignement',
      controlType: PropertyControlType.dropdown,
      options: [
        'center',
        'topLeft',
        'topCenter',
        'topRight',
        'centerLeft',
        'centerRight',
        'bottomLeft',
        'bottomCenter',
        'bottomRight',
      ],
      allowNull: true,
    ),
    PropertyFieldConfig(
      key: 'borderRadius',
      label: 'Rayon de bordure',
      controlType: PropertyControlType.number,
      allowNull: true,
      min: 0,
      suffix: 'px',
    ),
  ],
  'Text': [
    PropertyFieldConfig(
      key: 'data',
      label: 'Texte',
      controlType: PropertyControlType.multilineText,
    ),
    PropertyFieldConfig(
      key: 'fontSize',
      label: 'Taille de police',
      controlType: PropertyControlType.number,
      min: 1,
      suffix: 'px',
    ),
    PropertyFieldConfig(
      key: 'fontWeight',
      label: 'Poids',
      controlType: PropertyControlType.dropdown,
      options: ['normal', 'bold', '100', '200', '300', '400', '500', '600', '700', '800', '900'],
      allowNull: true,
    ),
    PropertyFieldConfig(
      key: 'fontStyle',
      label: 'Style',
      controlType: PropertyControlType.dropdown,
      options: ['normal', 'italic'],
      allowNull: true,
    ),
    PropertyFieldConfig(
      key: 'color',
      label: 'Couleur',
      controlType: PropertyControlType.color,
      defaultValue: '#FF000000',
    ),
    PropertyFieldConfig(
      key: 'textAlign',
      label: 'Alignement du texte',
      controlType: PropertyControlType.dropdown,
      options: ['left', 'right', 'center', 'justify'],
      allowNull: true,
    ),
    PropertyFieldConfig(
      key: 'maxLines',
      label: 'Lignes max',
      controlType: PropertyControlType.number,
      allowNull: true,
      min: 1,
      allowDecimal: false,
    ),
    PropertyFieldConfig(
      key: 'overflow',
      label: 'Débordement',
      controlType: PropertyControlType.dropdown,
      options: ['clip', 'ellipsis', 'fade'],
      allowNull: true,
    ),
  ],
  'Row': [
    PropertyFieldConfig(
      key: 'mainAxisAlignment',
      label: 'Alignement principal',
      controlType: PropertyControlType.dropdown,
      options: ['start', 'center', 'end', 'spaceBetween', 'spaceAround', 'spaceEvenly'],
      allowNull: true,
    ),
    PropertyFieldConfig(
      key: 'crossAxisAlignment',
      label: 'Alignement secondaire',
      controlType: PropertyControlType.dropdown,
      options: ['start', 'center', 'end', 'stretch'],
      allowNull: true,
    ),
    PropertyFieldConfig(
      key: 'mainAxisSize',
      label: 'Taille de l\'axe principal',
      controlType: PropertyControlType.dropdown,
      options: ['max', 'min'],
      allowNull: true,
    ),
  ],
  'Column': [
    PropertyFieldConfig(
      key: 'mainAxisAlignment',
      label: 'Alignement principal',
      controlType: PropertyControlType.dropdown,
      options: ['start', 'center', 'end', 'spaceBetween', 'spaceAround', 'spaceEvenly'],
      allowNull: true,
    ),
    PropertyFieldConfig(
      key: 'crossAxisAlignment',
      label: 'Alignement secondaire',
      controlType: PropertyControlType.dropdown,
      options: ['start', 'center', 'end', 'stretch'],
      allowNull: true,
    ),
    PropertyFieldConfig(
      key: 'mainAxisSize',
      label: 'Taille de l\'axe principal',
      controlType: PropertyControlType.dropdown,
      options: ['max', 'min'],
      allowNull: true,
    ),
  ],
  'Button': [
    PropertyFieldConfig(
      key: 'text',
      label: 'Texte du bouton',
      controlType: PropertyControlType.text,
    ),
    PropertyFieldConfig(
      key: 'buttonType',
      label: 'Type',
      controlType: PropertyControlType.dropdown,
      options: ['elevated', 'text', 'outlined'],
    ),
    PropertyFieldConfig(
      key: 'color',
      label: 'Couleur de fond',
      controlType: PropertyControlType.color,
      defaultValue: '#FF6200EE',
    ),
    PropertyFieldConfig(
      key: 'textColor',
      label: 'Couleur du texte',
      controlType: PropertyControlType.color,
      defaultValue: '#FFFFFFFF',
    ),
  ],
  'Image': [
    PropertyFieldConfig(
      key: 'src',
      label: 'Source (URL ou asset)',
      controlType: PropertyControlType.text,
    ),
    PropertyFieldConfig(
      key: 'width',
      label: 'Largeur',
      controlType: PropertyControlType.number,
      allowNull: true,
      min: 0,
      suffix: 'dp',
    ),
    PropertyFieldConfig(
      key: 'height',
      label: 'Hauteur',
      controlType: PropertyControlType.number,
      allowNull: true,
      min: 0,
      suffix: 'dp',
    ),
    PropertyFieldConfig(
      key: 'fit',
      label: 'Ajustement',
      controlType: PropertyControlType.dropdown,
      options: ['cover', 'contain', 'fill', 'none', 'scaleDown'],
      allowNull: true,
    ),
  ],
  'Icon': [
    PropertyFieldConfig(
      key: 'icon',
      label: 'Icône',
      controlType: PropertyControlType.icon,
    ),
    PropertyFieldConfig(
      key: 'color',
      label: 'Couleur',
      controlType: PropertyControlType.color,
      defaultValue: '#FF000000',
    ),
    PropertyFieldConfig(
      key: 'size',
      label: 'Taille',
      controlType: PropertyControlType.number,
      min: 1,
      suffix: 'px',
      defaultValue: 24,
    ),
  ],
  'TextField': [
    PropertyFieldConfig(
      key: 'hintText',
      label: 'Indice',
      controlType: PropertyControlType.text,
      allowNull: true,
    ),
    PropertyFieldConfig(
      key: 'obscureText',
      label: 'Masquer le texte',
      controlType: PropertyControlType.boolean,
      defaultValue: false,
    ),
    PropertyFieldConfig(
      key: 'keyboardType',
      label: 'Type de clavier',
      controlType: PropertyControlType.dropdown,
      options: ['text', 'number', 'email', 'phone'],
      allowNull: true,
    ),
    PropertyFieldConfig(
      key: 'maxLines',
      label: 'Lignes max',
      controlType: PropertyControlType.number,
      allowNull: true,
      min: 1,
      allowDecimal: false,
    ),
  ],
  'Checkbox': [
    PropertyFieldConfig(
      key: 'value',
      label: 'Coché',
      controlType: PropertyControlType.boolean,
      defaultValue: false,
    ),
  ],
  'Switch': [
    PropertyFieldConfig(
      key: 'value',
      label: 'Activé',
      controlType: PropertyControlType.boolean,
      defaultValue: false,
    ),
  ],
  'Slider': [
    PropertyFieldConfig(
      key: 'min',
      label: 'Minimum',
      controlType: PropertyControlType.number,
      defaultValue: 0,
      min: 0,
    ),
    PropertyFieldConfig(
      key: 'max',
      label: 'Maximum',
      controlType: PropertyControlType.number,
      defaultValue: 100,
      min: 0,
    ),
    PropertyFieldConfig(
      key: 'value',
      label: 'Valeur',
      controlType: PropertyControlType.number,
      defaultValue: 0,
      min: 0,
    ),
  ],
  'ListView': [
    PropertyFieldConfig(
      key: 'scrollDirection',
      label: 'Direction',
      controlType: PropertyControlType.dropdown,
      options: ['vertical', 'horizontal'],
      allowNull: true,
    ),
    PropertyFieldConfig(
      key: 'padding',
      label: 'Padding',
      controlType: PropertyControlType.text,
      allowNull: true,
    ),
    PropertyFieldConfig(
      key: 'reverse',
      label: 'Inverser',
      controlType: PropertyControlType.boolean,
      defaultValue: false,
    ),
  ],
  'GridView': [
    PropertyFieldConfig(
      key: 'crossAxisCount',
      label: 'Colonnes',
      controlType: PropertyControlType.number,
      min: 1,
      allowDecimal: false,
      defaultValue: 2,
    ),
    PropertyFieldConfig(
      key: 'spacing',
      label: 'Espacement',
      controlType: PropertyControlType.number,
      min: 0,
      suffix: 'px',
      defaultValue: 0,
    ),
    PropertyFieldConfig(
      key: 'runSpacing',
      label: 'Espacement vertical',
      controlType: PropertyControlType.number,
      min: 0,
      suffix: 'px',
      defaultValue: 0,
    ),
  ],
  'ListTile': [
    PropertyFieldConfig(
      key: 'title',
      label: 'Titre',
      controlType: PropertyControlType.text,
    ),
    PropertyFieldConfig(
      key: 'subtitle',
      label: 'Sous-titre',
      controlType: PropertyControlType.text,
      allowNull: true,
    ),
    PropertyFieldConfig(
      key: 'leading',
      label: 'Icône avant',
      controlType: PropertyControlType.icon,
      allowNull: true,
    ),
    PropertyFieldConfig(
      key: 'trailing',
      label: 'Icône après',
      controlType: PropertyControlType.icon,
      allowNull: true,
    ),
  ],
  'Scaffold': [
    PropertyFieldConfig(
      key: 'backgroundColor',
      label: 'Couleur de fond',
      controlType: PropertyControlType.color,
      defaultValue: '#FFFFFFFF',
    ),
  ],
  'AppBar': [
    PropertyFieldConfig(
      key: 'title',
      label: 'Titre',
      controlType: PropertyControlType.text,
    ),
    PropertyFieldConfig(
      key: 'backgroundColor',
      label: 'Couleur de fond',
      controlType: PropertyControlType.color,
      defaultValue: '#FF6200EE',
    ),
  ],
};

/// Panneau d'inspection des propriétés d'un widget sélectionné.
///
/// Ce widget affiche dynamiquement les propriétés éditables du widget en
/// fonction de son type. Il utilise la configuration [_widgetPropertyFields]
/// pour générer les contrôles appropriés.
class PropertyInspector extends StatelessWidget {
  /// Widget sélectionné (peut être null).
  final WidgetNode? selectedWidget;

  /// Callback appelé lorsqu'une propriété est modifiée.
  /// [key] : clé de la propriété.
  /// [value] : nouvelle valeur.
  final ValueChanged<String, dynamic> onPropertyChanged;

  /// Callback optionnel pour supprimer le widget.
  final VoidCallback? onDelete;

  /// Callback optionnel pour dupliquer le widget.
  final VoidCallback? onDuplicate;

  const PropertyInspector({
    super.key,
    required this.selectedWidget,
    required this.onPropertyChanged,
    this.onDelete,
    this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedWidget == null) {
      return const Center(
        child: Text('Aucun widget sélectionné'),
      );
    }

    final widget = selectedWidget!;
    final fields = _widgetPropertyFields[widget.type] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête avec type et ID
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.type,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'ID: ${widget.id}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                  ],
                ),
              ),
              if (onDuplicate != null)
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'Dupliquer',
                  onPressed: onDuplicate,
                ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Supprimer',
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: fields.map((field) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildField(context, widget, field),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Construit un contrôle pour un champ de propriété donné.
  Widget _buildField(
    BuildContext context,
    WidgetNode widget,
    PropertyFieldConfig field,
  ) {
    final properties = widget.properties ?? {};
    final value = properties.containsKey(field.key)
        ? properties[field.key]
        : field.defaultValue;

    switch (field.controlType) {
      case PropertyControlType.text:
        return _buildTextField(context, field, value);

      case PropertyControlType.multilineText:
        return _buildMultilineTextField(context, field, value);

      case PropertyControlType.number:
        return NumberInput(
          label: field.label,
          value: value is num ? value.toDouble() : null,
          onChanged: (newValue) => onPropertyChanged(field.key, newValue),
          min: field.min,
          max: field.max,
          allowDecimal: field.allowDecimal,
          allowNull: field.allowNull,
          suffix: field.suffix,
          showSlider: field.showSlider,
        );

      case PropertyControlType.color:
        // For color, we need a default color value if null.
        final colorString = value as String? ?? '#FFFFFFFF';
        return ColorPicker(
          label: field.label,
          initialColor: parseColor(colorString),
          onColorChanged: (color) {
            onPropertyChanged(field.key, colorToHex(color));
          },
        );

      case PropertyControlType.dropdown:
        return DropdownInput<dynamic>.simple(
          label: field.label,
          value: value,
          options: field.options ?? [],
          labelFor: (opt) => field.optionLabel?.call(opt) ?? opt.toString(),
          onChanged: (newValue) => onPropertyChanged(field.key, newValue),
          allowNull: field.allowNull,
        );

      case PropertyControlType.icon:
        return IconPicker(
          label: field.label,
          initialIconName: value as String? ?? 'home',
          onIconChanged: (newIcon) => onPropertyChanged(field.key, newIcon),
        );

      case PropertyControlType.boolean:
        return SwitchListTile(
          title: Text(field.label),
          value: value is bool ? value : false,
          onChanged: (newVal) => onPropertyChanged(field.key, newVal),
          contentPadding: EdgeInsets.zero,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  /// Champ texte simple.
  Widget _buildTextField(
    BuildContext context,
    PropertyFieldConfig field,
    dynamic value,
  ) {
    final controller = TextEditingController(text: value?.toString() ?? '');
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: field.label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onSubmitted: (newValue) => onPropertyChanged(field.key, newValue),
      onChanged: (newValue) => onPropertyChanged(field.key, newValue),
    );
  }

  /// Champ texte multiligne.
  Widget _buildMultilineTextField(
    BuildContext context,
    PropertyFieldConfig field,
    dynamic value,
  ) {
    final controller = TextEditingController(text: value?.toString() ?? '');
    return TextField(
      controller: controller,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        labelText: field.label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onSubmitted: (newValue) => onPropertyChanged(field.key, newValue),
      onChanged: (newValue) => onPropertyChanged(field.key, newValue),
    );
  }
}