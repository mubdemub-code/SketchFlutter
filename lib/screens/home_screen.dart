import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../models/project_metadata.dart';
import '../providers/project_provider.dart';
import '../widgets/project_card.dart';

/// Écran d'accueil de l'éditeur : affiche la liste des projets.
///
/// Cet écran utilise le provider [projectListProvider] pour charger les métadonnées
/// de tous les projets locaux et les afficher dans une grille.
///
/// L'utilisateur peut :
///   - créer un nouveau projet via le bouton flottant,
///   - ouvrir un projet en tapant sur sa carte,
///   - renommer, dupliquer, exporter ou supprimer via le menu contextuel,
///   - importer un projet .mub (fonctionnalité à venir).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Affiche le dialogue de création d'un nouveau projet.
  Future<void> _showCreateProjectDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(AppStrings.newProject),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppStrings.projectName,
              hintText: 'Ex: Ma super application',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(AppStrings.ok),
            ),
          ],
        );
      },
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      // Appeler l'action de création de projet.
      await ref
          .read(
            createProjectAction(
              (
                name: controller.text.trim(),
                description: null,
                author: null,
                packageName: null,
              ),
            ).future,
          )
          .then((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Projet créé avec succès')),
          );
        }
      }).catchError((e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e')),
          );
        }
      });
    }
  }

  /// Affiche le dialogue de confirmation de suppression.
  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    ProjectMetadata project,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(AppStrings.deleteProject),
          content: Text(
            'Voulez-vous vraiment supprimer "${project.name}" ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(AppStrings.deleteProject),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await ref
          .read(deleteProjectAction(project.projectId!).future)
          .then((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Projet supprimé')),
          );
        }
      }).catchError((e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.homeTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: AppStrings.importProject,
            onPressed: () {
              // TODO: Implémenter l'import de fichier .mub
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Import à venir')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Erreur lors du chargement : $err',
                style: const TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(projectListProvider),
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
        ),
        data: (projects) {
          if (projects.isEmpty) {
            return _buildEmptyState(context);
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return ProjectCard(
                metadata: project,
                onTap: () {
                  // TODO: Naviguer vers l'éditeur avec ce projet
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ouverture de ${project.name}')),
                  );
                },
                onRename: () {
                  // TODO: Afficher un dialog de renommage
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Renommage à venir')),
                  );
                },
                onDuplicate: () {
                  // TODO: Dupliquer le projet
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Duplication à venir')),
                  );
                },
                onExport: () {
                  // TODO: Exporter le projet en .mub
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export à venir')),
                  );
                },
                onDelete: () => _showDeleteConfirmation(context, ref, project),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateProjectDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.newProject),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  /// Construit l'état vide lorsque aucun projet n'existe.
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimary : Colors.black87;
    final secondaryTextColor = isDark ? AppColors.textSecondary : Colors.black54;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.widgets_outlined,
            size: 100,
            color: AppColors.accent.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.noProjects,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.noProjectsSubtitle,
            style: TextStyle(
              color: secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Import de SettingsScreen (à déplacer dans un fichier séparé si nécessaire)
// Pour l'instant, on suppose que settings_screen.dart existe.
// Nous allons l'importer en haut.
import 'settings_screen.dart';