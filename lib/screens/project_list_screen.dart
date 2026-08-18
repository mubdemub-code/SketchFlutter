import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../models/project_metadata.dart';
import '../providers/project_provider.dart';
import '../widgets/project_card.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';

/// Écran de liste des projets.
///
/// Affiche tous les projets locaux sous forme de grille. Permet de :
///   - créer un nouveau projet (bouton flottant),
///   - ouvrir un projet (tap sur la carte),
///   - renommer, dupliquer, exporter, supprimer (menu contextuel),
///   - importer un projet .mub (bouton dans l'AppBar, placeholder).
///
/// Cet écran utilise le provider [projectListProvider] pour charger les
/// métadonnées et les actions associées pour les opérations CRUD.
class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key});

  /// Ouvre le dialogue de création d'un nouveau projet.
  Future<void> _showCreateProjectDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(AppStrings.newProject),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
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
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: AppStrings.projectDescription,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
              ),
            ],
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

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await ref
            .read(
              createProjectAction(
                (
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
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
        });
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e')),
          );
        }
      }
    }
  }

  /// Affiche le dialogue de confirmation de suppression.
  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    ProjectMetadata project,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(AppStrings.deleteProject),
          content: Text('Voulez-vous vraiment supprimer "${project.name}" ?'),
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

    if (confirmed == true) {
      try {
        await ref.read(deleteProjectAction(project.projectId!).future);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Projet supprimé')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e')),
          );
        }
      }
    }
  }

  /// Ouvre un projet : charge le projet et navigue vers l'éditeur.
  Future<void> _openProject(
    BuildContext context,
    WidgetRef ref,
    String projectId,
  ) async {
    // Afficher un indicateur de chargement.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await ref.read(openProjectAction(projectId).future);
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Fermer le dialogue
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const EditorScreen()),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'ouverture : $e')),
      );
    }
  }

  /// Affiche le dialogue de renommage d'un projet.
  Future<void> _showRenameProjectDialog(
    BuildContext context,
    WidgetRef ref,
    ProjectMetadata project,
  ) async {
    final controller = TextEditingController(text: project.name);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(AppStrings.renameProject),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppStrings.projectName,
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
      // Récupérer le projet complet, modifier le nom, et sauvegarder.
      final storage = ref.read(projectStorageProvider);
      final fullProject = await storage.loadProject(project.projectId!);
      if (fullProject == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Projet introuvable')),
          );
        }
        return;
      }
      final updatedProject = fullProject.copyWith(
        metadata: fullProject.metadata.copyWith(
          name: controller.text.trim(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await ref.read(saveActiveProjectAction(updatedProject).future);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Projet renommé')),
        );
      }
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
                onTap: () => _openProject(context, ref, project.projectId!),
                onRename: () => _showRenameProjectDialog(context, ref, project),
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