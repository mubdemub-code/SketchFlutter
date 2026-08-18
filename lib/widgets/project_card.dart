import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../models/project_metadata.dart';

/// Carte de projet affichée dans la grille/liste des projets.
///
/// Cette carte présente les informations essentielles d'un projet :
///   - miniature (si disponible) ou icône par défaut,
///   - nom du projet,
///   - date de dernière modification,
///   - description (si présente).
///
/// Elle expose des callbacks pour les actions utilisateur :
///   - [onTap] : ouverture du projet.
///   - [onRename], [onDuplicate], [onDelete], [onExport] : actions du menu contextuel.
///
/// Le widget est conçu pour être utilisé dans une grille ou une liste,
/// avec un style adapté au thème de l'éditeur (mode sombre par défaut).
class ProjectCard extends StatelessWidget {
  /// Métadonnées du projet à afficher.
  final ProjectMetadata metadata;

  /// Callback appelé lorsque l'utilisateur tape sur la carte.
  final VoidCallback? onTap;

  /// Callback pour l'action "Renommer".
  final VoidCallback? onRename;

  /// Callback pour l'action "Dupliquer".
  final VoidCallback? onDuplicate;

  /// Callback pour l'action "Supprimer".
  final VoidCallback? onDelete;

  /// Callback pour l'action "Exporter".
  final VoidCallback? onExport;

  /// Indique si la carte doit être affichée en mode compact (liste).
  final bool compact;

  const ProjectCard({
    super.key,
    required this.metadata,
    this.onTap,
    this.onRename,
    this.onDuplicate,
    this.onDelete,
    this.onExport,
    this.compact = false,
  });

  /// Formate la date de modification en chaîne lisible.
  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    if (dateDay == today) {
      return 'Aujourd\'hui';
    } else if (dateDay == today.subtract(const Duration(days: 1))) {
      return 'Hier';
    } else {
      // Format simple : jour/mois/année
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      return '$day/$month/$year';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.surface : Colors.white;
    final textColor = isDark ? AppColors.textPrimary : Colors.black87;
    final secondaryTextColor = isDark ? AppColors.textSecondary : Colors.black54;

    // Si compact, on utilise une ListTile simplifiée.
    if (compact) {
      return Card(
        color: backgroundColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: _buildThumbnail(theme),
          title: Text(
            metadata.name,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            AppStrings.lastModified + ': ' + _formatDate(metadata.updatedAt),
            style: TextStyle(color: secondaryTextColor, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _buildPopupMenu(),
          onTap: onTap,
        ),
      );
    }

    // Mode normal (grille) : carte verticale.
    return Card(
      color: backgroundColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniature ou placeholder
            Expanded(
              child: Container(
                width: double.infinity,
                color: isDark ? AppColors.surfaceLight : Colors.grey[200],
                child: _buildThumbnail(theme, size: 100),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          metadata.name,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildPopupMenu(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.lastModified + ': ' + _formatDate(metadata.updatedAt),
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (metadata.description != null &&
                      metadata.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      metadata.description!,
                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit l'aperçu de la miniature si disponible, sinon une icône par défaut.
  Widget _buildThumbnail(ThemeData theme, {double size = 40}) {
    if (metadata.thumbnailBase64 != null && metadata.thumbnailBase64!.isNotEmpty) {
      // Décodage base64 en Image.memory
      try {
        final bytes = base64Decode(metadata.thumbnailBase64!);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.widgets_outlined,
            size: size,
            color: theme.colorScheme.primary,
          ),
        );
      } catch (_) {
        // Fallback si base64 invalide
      }
    }
    return Icon(
      Icons.widgets_outlined,
      size: size,
      color: theme.colorScheme.primary,
    );
  }

  /// Construit le menu contextuel avec les actions disponibles.
  Widget _buildPopupMenu() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'rename':
            onRename?.call();
            break;
          case 'duplicate':
            onDuplicate?.call();
            break;
          case 'export':
            onExport?.call();
            break;
          case 'delete':
            onDelete?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        if (onRename != null)
          PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text(AppStrings.renameProject),
              dense: true,
            ),
          ),
        if (onDuplicate != null)
          PopupMenuItem(
            value: 'duplicate',
            child: ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text(AppStrings.duplicateProject),
              dense: true,
            ),
          ),
        if (onExport != null)
          PopupMenuItem(
            value: 'export',
            child: ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text(AppStrings.exportProject),
              dense: true,
            ),
          ),
        if (onDelete != null)
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(AppStrings.deleteProject, style: TextStyle(color: Colors.red)),
              dense: true,
            ),
          ),
      ],
      icon: const Icon(Icons.more_vert),
      tooltip: 'Actions',
    );
  }
}