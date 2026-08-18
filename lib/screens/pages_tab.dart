import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../models/page_model.dart';
import '../models/project_model.dart';
import '../providers/project_provider.dart';

/// Onglet Pages de l'éditeur.
///
/// Permet de gérer les pages (écrans) du projet :
///   - ajouter une nouvelle page,
///   - renommer une page,
///   - supprimer une page (sauf s'il n'en reste qu'une),
///   - définir la page initiale.
///
/// L'onglet travaille directement sur le projet actif via le provider
/// [activeProjectProvider]. Toute modification est immédiatement répercutée
/// dans le projet et donc dans l'ensemble de l'éditeur.
class PagesTab extends ConsumerWidget {
  /// Projet actif (non null, fourni par l'éditeur).
  final ProjectModel project;

  const PagesTab({super.key, required this.project});

  /// Affiche le dialogue pour ajouter une nouvelle page.
  Future<void> _showAddPageDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(AppStrings.addPage),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppStrings.pageName,
              hintText: 'Ex: Détails',
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
      final name = controller.text.trim();
      // Créer une nouvelle page avec un widget racine par défaut.
      final newPage = PageModel.create(name: name);
      // Ajouter la page au projet.
      final notifier = ref.read(activeProjectProvider.notifier);
      notifier.state = project.addPage(newPage);
    }
  }

  /// Affiche le dialogue pour renommer une page existante.
  Future<void> _showRenamePageDialog(
    BuildContext context,
    WidgetRef ref,
    PageModel page,
  ) async {
    final controller = TextEditingController(text: page.name);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(AppStrings.renameProject),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppStrings.pageName,
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
      final newName = controller.text.trim();
      // Créer une copie de la page avec le nouveau nom.
      final updatedPage = page.copyWith(name: newName);
      // Remplacer la page dans la liste des pages.
      final updatedPages = project.pages
          .map((p) => p.id == updatedPage.id ? updatedPage : p)
          .toList();
      final updatedProject = project.copyWith(pages: updatedPages);
      ref.read(activeProjectProvider.notifier).state = updatedProject;
    }
  }

  /// Supprime une page après confirmation.
  /// Empêche la suppression de la dernière page.
  Future<void> _deletePage(
    BuildContext context,
    WidgetRef ref,
    PageModel page,
  ) async {
    if (project.pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de supprimer la seule page du projet.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer la page'),
          content: Text('Voulez-vous vraiment supprimer "${page.name}" ?'),
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
      final updatedProject = project.removePage(page.id);
      ref.read(activeProjectProvider.notifier).state = updatedProject;
    }
  }

  /// Définit une page comme page initiale.
  /// Met à jour la navigation et le flag `isInitial` sur les pages.
  void _setInitialPage(WidgetRef ref, String pageId) {
    // Mettre à jour la navigation.
    final updatedNavigation = project.navigation.copyWith(initialPageId: pageId);
    // Mettre à jour le flag isInitial sur chaque page.
    final updatedPages = project.pages.map((p) {
      return p.copyWith(isInitial: p.id == pageId);
    }).toList();
    // Construire le projet mis à jour.
    final updatedProject = project.copyWith(
      navigation: updatedNavigation,
      pages: updatedPages,
    );
    // Remplacer le projet actif.
    ref.read(activeProjectProvider.notifier).state = updatedProject;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = project.pages;
    final initialPageId = project.navigation.initialPageId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête avec titre et bouton d'ajout.
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.pagesTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              FilledButton.icon(
                onPressed: () => _showAddPageDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text(AppStrings.addPage),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Liste des pages.
        Expanded(
          child: pages.isEmpty
              ? Center(
                  child: Text(
                    'Aucune page. Ajoutez une page pour commencer.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.builder(
                  itemCount: pages.length,
                  itemBuilder: (context, index) {
                    final page = pages[index];
                    final isInitial = page.id == initialPageId || page.isInitial;
                    return Card(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.surface
                          : Colors.white,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: Icon(
                          isInitial ? Icons.home : Icons.description_outlined,
                          color: isInitial ? AppColors.accent : null,
                        ),
                        title: Text(page.name),
                        subtitle: Text(
                          isInitial ? AppStrings.initialPage : '',
                          style: TextStyle(
                            color: isInitial ? AppColors.accent : null,
                            fontSize: 12,
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'rename':
                                _showRenamePageDialog(context, ref, page);
                                break;
                              case 'delete':
                                _deletePage(context, ref, page);
                                break;
                              case 'set_initial':
                                _setInitialPage(ref, page.id);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            if (!isInitial)
                              PopupMenuItem(
                                value: 'set_initial',
                                child: ListTile(
                                  leading: const Icon(Icons.home_outlined),
                                  title: const Text(AppStrings.setAsInitial),
                                  dense: true,
                                ),
                              ),
                            PopupMenuItem(
                              value: 'rename',
                              child: ListTile(
                                leading: const Icon(Icons.edit_outlined),
                                title: const Text(AppStrings.renameProject),
                                dense: true,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                title: const Text(
                                  AppStrings.deleteProject,
                                  style: TextStyle(color: Colors.red),
                                ),
                                dense: true,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          // Optionnel : on pourrait sélectionner la page pour l'éditer.
                          // Pour l'instant, rien.
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}