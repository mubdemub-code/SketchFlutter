import 'package:flutter/material.dart';

/// Widget de saisie numérique avec validation et optionnellement un curseur.
///
/// Ce widget est utilisé dans l'inspecteur de propriétés pour éditer des
/// valeurs numériques (largeur, hauteur, fontSize, padding, etc.).
/// Il gère :
///   - la saisie libre dans un champ texte,
///   - la validation (entier ou décimal, bornes min/max),
///   - la possibilité de laisser vide si [allowNull] est vrai,
///   - un curseur ([Slider]) si [showSlider] est vrai,
///   - un suffixe optionnel (ex: "px", "dp").
///
/// Exemple d'utilisation :
/// ```dart
/// NumberInput(
///   label: 'Largeur',
///   value: 100,
///   min: 0,
///   max: 500,
///   suffix: 'px',
///   onChanged: (newValue) { ... },
/// )
/// ```
class NumberInput extends StatefulWidget {
  /// Libellé optionnel affiché au-dessus du champ.
  final String? label;

  /// Valeur actuelle.
  final double? value;

  /// Callback appelé lorsque la valeur change.
  final ValueChanged<double?> onChanged;

  /// Valeur minimale autorisée (inclus).
  final double? min;

  /// Valeur maximale autorisée (inclus).
  final double? max;

  /// Autorise les nombres décimaux.
  final bool allowDecimal;

  /// Autorise la valeur nulle (champ vide).
  final bool allowNull;

  /// Texte de suffixe affiché après la valeur.
  final String? suffix;

  /// Affiche un curseur sous le champ.
  final bool showSlider;

  /// Pas du curseur.
  final double step;

  /// Nombre de décimales affichées lors du formatage.
  final int decimals;

  const NumberInput({
    super.key,
    this.label,
    required this.value,
    required this.onChanged,
    this.min,
    this.max,
    this.allowDecimal = true,
    this.allowNull = false,
    this.suffix,
    this.showSlider = false,
    this.step = 1.0,
    this.decimals = 2,
  });

  @override
  State<NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<NumberInput> {
  late TextEditingController _controller;
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.value));
  }

  @override
  void didUpdateWidget(NumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mettre à jour le texte si la valeur externe a changé et que le champ
    // n'est pas en cours d'édition.
    if (oldWidget.value != widget.value) {
      final currentText = _controller.text;
      final newText = _formatValue(widget.value);
      if (currentText != newText) {
        _controller.text = newText;
        _controller.selection = TextSelection.collapsed(offset: newText.length);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Formate une valeur en chaîne pour le champ texte.
  String _formatValue(double? value) {
    if (value == null) return '';
    if (!widget.allowDecimal) {
      return value.toInt().toString();
    }
    // Éviter les zéros inutiles (ex: 100.00 -> 100)
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(widget.decimals);
  }

  /// Parse la chaîne saisie et retourne une valeur double si valide.
  double? _parseValue(String text) {
    if (text.trim().isEmpty && widget.allowNull) {
      return null;
    }
    final parsed = double.tryParse(text.replaceAll(',', '.'));
    if (parsed == null) return null;
    // Vérification des bornes.
    if (widget.min != null && parsed < widget.min!) return null;
    if (widget.max != null && parsed > widget.max!) return null;
    // Si les décimales ne sont pas autorisées, vérifier que c'est un entier.
    if (!widget.allowDecimal && parsed != parsed.roundToDouble()) return null;
    return parsed;
  }

  void _onTextChanged(String text) {
    final parsed = _parseValue(text);
    setState(() {
      _isValid = parsed != null || (text.trim().isEmpty && widget.allowNull);
    });
    if (parsed != null || (text.trim().isEmpty && widget.allowNull)) {
      widget.onChanged(parsed);
    }
  }

  void _onSliderChanged(double newValue) {
    setState(() {
      _controller.text = _formatValue(newValue);
      _isValid = true;
    });
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = _isValid
        ? (isDark ? Colors.white24 : Colors.black26)
        : theme.colorScheme.error;

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
        TextField(
          controller: _controller,
          keyboardType: TextInputType.numberWithOptions(
            decimal: widget.allowDecimal,
            signed: widget.min != null && widget.min! < 0,
          ),
          style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
          decoration: InputDecoration(
            isDense: true,
            suffixText: widget.suffix,
            errorText: _isValid ? null : 'Valeur invalide',
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
          onChanged: _onTextChanged,
          onSubmitted: _onTextChanged,
        ),
        if (widget.showSlider)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Slider(
              value: (widget.value ?? widget.min ?? 0)
                  .clamp(widget.min ?? double.negativeInfinity, widget.max ?? double.infinity)
                  .toDouble(),
              min: widget.min ?? 0,
              max: widget.max ?? 100,
              onChanged: _onSliderChanged,
              divisions: widget.step > 0
                  ? ((widget.max ?? 100) - (widget.min ?? 0)) ~/ widget.step
                  : null,
              label: _formatValue(widget.value),
            ),
          ),
      ],
    );
  }
}