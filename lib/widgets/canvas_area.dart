import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// Zone de rendu en direct de l'éditeur.
///
/// Ce widget affiche la prévisualisation de l'interface utilisateur en cours
/// de conception. Il fournit un environnement de zoom et de déplacement
/// (pan) grâce à [InteractiveViewer], ainsi que des contrôles de zoom.
///
/// Le widget à afficher est passé via [child]. Il est généralement construit
/// par le moteur de rendu (parseur JSON → Widget) à l'extérieur.
///
/// L'utilisateur peut :
///   - pincer pour zoomer/dézoomer,
///   - faire glisser avec deux doigts pour se déplacer,
///   - utiliser les boutons +/- pour ajuster le zoom,
///   - double-taper pour réinitialiser le zoom.
///
/// Un clic sur la zone vide (pas sur un widget) peut être capturé via
/// [onBackgroundTap] pour désélectionner.
class CanvasArea extends StatefulWidget {
  /// Le widget à afficher (prévisualisation).
  final Widget child;

  /// Callback appelé lorsque l'utilisateur tape sur le fond (zone vide).
  final VoidCallback? onBackgroundTap;

  /// Couleur de fond de la toile.
  final Color backgroundColor;

  /// Afficher une grille de fond légère (comme un damier).
  final bool showGrid;

  /// Constructeur.
  const CanvasArea({
    super.key,
    required this.child,
    this.onBackgroundTap,
    this.backgroundColor = AppColors.background,
    this.showGrid = true,
  });

  @override
  State<CanvasArea> createState() => _CanvasAreaState();
}

class _CanvasAreaState extends State<CanvasArea> {
  final TransformationController _transformationController =
      TransformationController();

  static const double _minZoom = 0.1;
  static const double _maxZoom = 5.0;
  static const double _zoomStep = 0.2;

  double get _currentZoom => _transformationController.value.getMaxScaleOnAxis();

  /// Applique un nouveau facteur de zoom en le bornant.
  void _setZoom(double zoom) {
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    _transformationController.value = Matrix4.identity()
      ..scale(clamped, clamped);
    setState(() {});
  }

  void _zoomIn() {
    _setZoom(_currentZoom + _zoomStep);
  }

  void _zoomOut() {
    _setZoom(_currentZoom - _zoomStep);
  }

  void _resetZoom() {
    _setZoom(1.0);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Fond de la toile (avec éventuellement une grille).
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onBackgroundTap,
            child: Container(
              color: widget.backgroundColor,
              child: widget.showGrid ? _buildGridBackground() : null,
            ),
          ),
        ),
        // Zone de prévisualisation interactive.
        Positioned.fill(
          child: InteractiveViewer(
            transformationController: _transformationController,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(200),
            minScale: _minZoom,
            maxScale: _maxZoom,
            child: Center(
              child: widget.child,
            ),
          ),
        ),
        // Contrôles de zoom (en bas à droite).
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildZoomButton(Icons.add, _zoomIn, 'Zoom avant'),
              const SizedBox(height: 4),
              _buildZoomButton(Icons.remove, _zoomOut, 'Zoom arrière'),
              const SizedBox(height: 4),
              _buildZoomButton(Icons.refresh, _resetZoom, 'Réinitialiser le zoom'),
            ],
          ),
        ),
        // Indicateur de zoom (en haut à droite).
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${(_currentZoom * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Construit une grille de fond (damier léger).
  Widget _buildGridBackground() {
    return CustomPaint(
      painter: _GridPainter(
        gridColor: Colors.white.withOpacity(0.05),
        spacing: 20,
      ),
    );
  }

  /// Bouton de contrôle de zoom.
  Widget _buildZoomButton(IconData icon, VoidCallback onPressed, String tooltip) {
    return Material(
      color: Colors.black54,
      shape: CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Peintre personnalisé pour dessiner une grille de fond.
class _GridPainter extends CustomPainter {
  final Color gridColor;
  final double spacing;

  const _GridPainter({
    required this.gridColor,
    required this.spacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.gridColor != gridColor ||
        oldDelegate.spacing != spacing;
  }
}