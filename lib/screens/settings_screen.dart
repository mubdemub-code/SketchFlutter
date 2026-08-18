import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';

/// Écran des paramètres de l'éditeur.
///
/// Permet à l'utilisateur de configurer certaines préférences globales :
///   - Mode sombre (activé par défaut),
///   - Langue (pour l'instant uniquement le français),
///   - Sauvegarde automatique (activée par défaut),
///   - À propos et informations sur l'application.
///
/// Cet écran utilise un simple [StatefulWidget] ; plus tard, il pourra être
/// connecté à un provider de préférences (ex: `shared_preferences`).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // État local des préférences (sera remplacé par un stockage persistant plus tard).
  bool _darkMode = true;
  bool _autosave = true;
  String _language = 'fr'; // seul le français est supporté pour l'instant

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimary : Colors.black87;
    final secondaryTextColor = isDark ? AppColors.textSecondary : Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settingsTitle),
      ),
      body: ListView(
        children: [
          // Section Apparence
          _buildSectionHeader('Apparence', secondaryTextColor),
          SwitchListTile(
            title: Text(AppStrings.darkMode, style: TextStyle(color: textColor)),
            subtitle: Text(
              'Activer le mode sombre',
              style: TextStyle(color: secondaryTextColor),
            ),
            value: _darkMode,
            onChanged: (value) {
              setState(() {
                _darkMode = value;
                // TODO: Appliquer le changement de thème global.
              });
            },
            activeColor: AppColors.accent,
          ),

          const Divider(),

          // Section Édition
          _buildSectionHeader('Édition', secondaryTextColor),
          SwitchListTile(
            title: Text(AppStrings.autosave, style: TextStyle(color: textColor)),
            subtitle: Text(
              'Sauvegarder automatiquement les modifications',
              style: TextStyle(color: secondaryTextColor),
            ),
            value: _autosave,
            onChanged: (value) {
              setState(() {
                _autosave = value;
                // TODO: Sauvegarder la préférence.
              });
            },
            activeColor: AppColors.accent,
          ),

          const Divider(),

          // Section Langue
          _buildSectionHeader('Langue', secondaryTextColor),
          ListTile(
            title: Text(AppStrings.language, style: TextStyle(color: textColor)),
            subtitle: Text(
              'Français',
              style: TextStyle(color: secondaryTextColor),
            ),
            trailing: const Icon(Icons.check, color: AppColors.accent),
            onTap: () {
              // Pour l'instant, seule la langue française est disponible.
              // TODO: Ajouter un sélecteur de langue.
            },
          ),

          const Divider(),

          // Section À propos
          _buildSectionHeader('À propos', secondaryTextColor),
          ListTile(
            leading: Icon(Icons.info_outline, color: textColor),
            title: Text(AppStrings.appName, style: TextStyle(color: textColor)),
            subtitle: Text(
              AppStrings.appSlogan,
              style: TextStyle(color: secondaryTextColor),
            ),
          ),
          ListTile(
            leading: Icon(Icons.schedule, color: textColor),
            title: Text(AppStrings.versionLabel, style: TextStyle(color: textColor)),
            subtitle: Text(
              AppStrings.appVersion,
              style: TextStyle(color: secondaryTextColor),
            ),
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: textColor),
            title: Text(AppStrings.privacyPolicy, style: TextStyle(color: textColor)),
            onTap: () {
              // TODO: Ouvrir la politique de confidentialité.
            },
          ),
          ListTile(
            leading: Icon(Icons.description_outlined, color: textColor),
            title: Text(AppStrings.termsOfService, style: TextStyle(color: textColor)),
            onTap: () {
              // TODO: Ouvrir les conditions d'utilisation.
            },
          ),
        ],
      ),
    );
  }

  /// Construit un en-tête de section.
  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}