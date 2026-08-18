import 'package:flutter/material.dart';

/// Widget de liste déroulante générique.
///
/// Ce widget est utilisé dans l'inspecteur de propriétés pour sélectionner
/// une valeur parmi une liste finie (alignement, type de bouton, orientation, etc.).
/// Il s'appuie sur le widget natif `DropdownButtonFormField` de Flutter et
/// ajoute une validation visuelle et un style cohérent avec l'éditeur.
///
/// Exemple d'utilisation simple :
/// ```dart
/// DropdownInput<String>(
///   label: 'Alignement',
///   value: 'center',
///   options: ['center', 'topLeft', 'topRight'],
///   labelFor: (value) => value,
///   onChanged: (newValue) { ... },
/// )
/// ```
///
/// Ou avec une liste d'objets personnalisés :
/// ```dart
/// DropdownInput<MyEnum>(
///   label: 'Type',
///   value: myEnum,
///   items: [
///     DropdownMenuItem(value: MyEnum.a, child: Text('A')),
///     DropdownMenuItem(value: MyEnum.b, child: Text('B')),
///   ],
///   onChanged: (newValue) { ... },
/// )
/// ```
class DropdownInput<T> extends StatefulWidget {
  /// Libellé optionnel affiché au-dessus du champ.
  final String? label;

  /// Valeur actuellement sélectionnée (peut être null si allowNull).
  final T? value;

  /// Liste des éléments de la liste déroulante (format Flutter standard).
  final List<DropdownMenuItem<T>>? items;

  /// Callback appelé lorsque la sélection change.
  final ValueChanged<T?> onChanged;

  /// Autorise la sélection d'une valeur nulle (affiche "Aucun" comme option).
  final bool allowNull;

  /// Texte d'indication lorsque aucune valeur n'est sélectionnée.
  final String? hint;

  /// Constructeur par défaut avec des [items] Flutter standard.
  const DropdownInput({
    super.key,
    this.label,
    required this.value,
    this.items,
    required this.onChanged,
    this.allowNull = false,
    this.hint,
  });

  /// Constructeur simplifié prenant une liste de valeurs et une fonction
  /// pour les afficher. Utile pour les types simples (String, enum, etc.).
  ///
  /// [options] : liste des valeurs possibles.
  /// [labelFor] : fonction qui convertit une valeur en libellé lisible.
  /// Si non fournie, la méthode `toString()` est utilisée.
  factory DropdownInput.simple({
    Key? key,
    String? label,
    required T? value,
    required List<T> options,
    required ValueChanged<T?> onChanged,
    String? Function(T value)? labelFor,
    bool allowNull = false,
    String? hint,
  }) {
    final items = options.map((option) {
      final label = labelFor?.call(option) ?? option.toString();
      return DropdownMenuItem<T>(
        value: option,
        child: Text(label),
      );
    }).toList();

    return DropdownInput<T>(
      key: key,
      label: label,
      value: value,
      items: items,
      onChanged: onChanged,
      allowNull: allowNull,
      hint: hint,
    );
  }

  @override
  State<DropdownInput<T>> createState() => _DropdownInputState<T>();
}

class _DropdownInputState<T> extends State<DropdownInput<T>> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white24 : Colors.black26;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              widget.label!,
              style: theme.textTheme.bodySmall,
            ),
          ),
        DropdownButtonFormField<T>(
          initialValue: widget.value,
          items: _buildItems(),
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }

  /// Construit la liste des items en tenant compte de `allowNull`.
  List<DropdownMenuItem<T>>? _buildItems() {
    final baseItems = widget.items ?? [];
    if (widget.allowNull) {
      final nullItem = DropdownMenuItem<T>(
        value: null,
        child: Text(
          widget.hint ?? 'Aucun',
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
      return [nullItem, ...baseItems];
    }
    return baseItems;
  }
}