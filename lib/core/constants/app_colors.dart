import 'package:flutter/material.dart';

/// Couleurs de l'interface utilisateur de l'éditeur SketchFlutter.
///
/// Ces constantes définissent la palette de couleurs de l'application.
/// Elles sont utilisées pour le thème, les surfaces, les accents et les états.
class AppColors {
  AppColors._(); // Classe non instanciable

  // ---------------------------------------------------------------------------
  // Couleurs de base (mode sombre par défaut)
  // ---------------------------------------------------------------------------

  /// Fond principal de l'application (mode sombre).
  static const Color background = Color(0xFF121212);

  /// Surface des cartes, panneaux et conteneurs.
  static const Color surface = Color(0xFF1E1E1E);

  /// Surface légèrement plus claire pour les éléments en surbrillance.
  static const Color surfaceLight = Color(0xFF2C2C2C);

  /// Couleur d'accent principale (bleu électrique).
  static const Color accent = Color(0xFF00B4D8);

  /// Couleur d'accent secondaire (violet).
  static const Color accentSecondary = Color(0xFF7C4DFF);

  /// Couleur pour les actions de succès.
  static const Color success = Color(0xFF4CAF50);

  /// Couleur pour les avertissements.
  static const Color warning = Color(0xFFFFA726);

  /// Couleur pour les erreurs.
  static const Color error = Color(0xFFE53935);

  /// Couleur pour les informations.
  static const Color info = Color(0xFF29B6F6);

  // ---------------------------------------------------------------------------
  // Textes et icônes
  // ---------------------------------------------------------------------------

  /// Texte principal (haute lisibilité sur fond sombre).
  static const Color textPrimary = Color(0xFFEEEEEE);

  /// Texte secondaire (moins contrasté).
  static const Color textSecondary = Color(0xFFB0B0B0);

  /// Texte désactivé ou placeholder.
  static const Color textDisabled = Color(0xFF6E6E6E);

  /// Icônes actives.
  static const Color iconActive = Color(0xFFEEEEEE);

  /// Icônes inactives.
  static const Color iconInactive = Color(0xFF6E6E6E);

  // ---------------------------------------------------------------------------
  // Bordures et séparateurs
  // ---------------------------------------------------------------------------

  /// Bordure fine (par défaut).
  static const Color border = Color(0xFF383838);

  /// Bordure plus visible pour les éléments sélectionnés.
  static const Color borderAccent = Color(0xFF00B4D8);

  /// Séparateur (divider).
  static const Color divider = Color(0xFF2C2C2C);

  // ---------------------------------------------------------------------------
  // États de widgets (sélection, survol, etc.)
  // ---------------------------------------------------------------------------

  /// Fond d'un widget sélectionné dans la toile.
  static const Color selectionBackground = Color(0x3300B4D8); // accent avec alpha 20%

  /// Bordure d'un widget sélectionné.
  static const Color selectionBorder = accent;

  /// Fond d'un widget survolé (hover).
  static const Color hoverBackground = Color(0x33FFFFFF); // blanc avec alpha 20%

  // ---------------------------------------------------------------------------
  // Couleurs spécifiques à la palette de widgets
  // ---------------------------------------------------------------------------

  /// Fond de la palette.
  static const Color paletteBackground = surface;

  /// Fond d'un item de palette sélectionné.
  static const Color paletteItemSelected = surfaceLight;

  /// Fond d'un item de palette non sélectionné.
  static const Color paletteItemDefault = Colors.transparent;

  // ---------------------------------------------------------------------------
  // Couleurs du mode clair (pour référence ultérieure)
  // ---------------------------------------------------------------------------

  /// Fond principal en mode clair.
  static const Color lightBackground = Color(0xFFF5F5F5);

  /// Surface en mode clair.
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Texte principal en mode clair.
  static const Color lightTextPrimary = Color(0xFF000000);

  /// Texte secondaire en mode clair.
  static const Color lightTextSecondary = Color(0xFF757575);
}