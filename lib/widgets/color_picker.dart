import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/color_utils.dart';

/// Widget de sélection de couleur.
///
/// Affiche un aperçu de la couleur actuelle avec un champ de saisie hexadécimale
/// et un bouton pour ouvrir un sélecteur de couleur complet.
///
/// Exemple d'utilisation :
/// ```dart
/// ColorPicker(
///   initialColor: Colors.blue,
///   onColorChanged: (color) { ... },
/// )
/// ```
class ColorPicker extends StatefulWidget {
  /// Couleur initiale.
  final Color initialColor;

  /// Callback appelé lorsque la couleur change.
  final ValueChanged<Color> onColorChanged;

  /// Libellé optionnel.
  final String? label;

  const ColorPicker({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
    this.label,
  });

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late Color _currentColor;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    _hexController = TextEditingController(
      text: ColorUtils.colorToHex(_currentColor),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialColor != widget.initialColor) {
      _currentColor = widget.initialColor;
      _hexController.text = ColorUtils.colorToHex(_currentColor);
    }
  }

  void _updateColor(Color color) {
    setState(() {
      _currentColor = color;
      _hexController.text = ColorUtils.colorToHex(color);
    });
    widget.onColorChanged(color);
  }

  void _onHexChanged(String value) {
    try {
      final color = ColorUtils.parseColor(value.trim());
      setState(() {
        _currentColor = color;
      });
      widget.onColorChanged(color);
    } catch (_) {
      // Ignorer les entrées invalides ; l'utilisateur verra le texte tel quel.
    }
  }

  Future<void> _openColorDialog() async {
    final selected = await showDialog<Color>(
      context: context,
      builder: (dialogContext) {
        return _ColorPickerDialog(initialColor: _currentColor);
      },
    );
    if (selected != null) {
      _updateColor(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              widget.label!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Row(
          children: [
            // Aperçu de la couleur
            InkWell(
              onTap: _openColorDialog,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _currentColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white24,
                    width: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Champ hexadécimal
            Expanded(
              child: TextField(
                controller: _hexController,
                style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: '#',
                  hintText: 'AARRGGBB',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onSubmitted: _onHexChanged,
                onChanged: _onHexChanged,
              ),
            ),
            // Bouton d'ouverture du sélecteur
            IconButton(
              icon: const Icon(Icons.palette_outlined),
              tooltip: 'Ouvrir le sélecteur',
              onPressed: _openColorDialog,
            ),
          ],
        ),
      ],
    );
  }
}

/// Boîte de dialogue de sélection de couleur.
///
/// Utilise les sliders RVB et un aperçu en temps réel.
class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const _ColorPickerDialog({required this.initialColor});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _red;
  late double _green;
  late double _blue;
  late double _alpha;

  @override
  void initState() {
    super.initState();
    // Correction de compatibilité Flutter 3.24.0 (utilisation de .red, .green, .blue, .alpha)
    _red = widget.initialColor.red.toDouble();
    _green = widget.initialColor.green.toDouble();
    _blue = widget.initialColor.blue.toDouble();
    _alpha = widget.initialColor.alpha.toDouble();
  }

  // Correction de compatibilité Flutter 3.24.0 (utilisation de Color.fromARGB)
  Color get _currentColor => Color.fromARGB(
        _alpha.round(),
        _red.round(),
        _green.round(),
        _blue.round(),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sélectionner une couleur'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Aperçu
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: _currentColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
            ),
            const SizedBox(height: 16),
            // Sliders RVB
            _buildSlider('Rouge', _red, Colors.red, (v) => setState(() => _red = v)),
            _buildSlider('Vert', _green, Colors.green, (v) => setState(() => _green = v)),
            _buildSlider('Bleu', _blue, Colors.blue, (v) => setState(() => _blue = v)),
            _buildSlider('Alpha', _alpha, Colors.grey, (v) => setState(() => _alpha = v)),
            const SizedBox(height: 8),
            // Code hexadécimal
            Text(
              ColorUtils.colorToHex(_currentColor),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_currentColor),
          child: const Text('OK'),
        ),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    Color activeColor,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(label, style: const TextStyle(fontSize: 14)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0, 255),
            min: 0,
            max: 255,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            value.round().toString(),
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
