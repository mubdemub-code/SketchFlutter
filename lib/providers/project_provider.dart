import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project_model.dart';
import '../models/project_metadata.dart';
import '../services/project_storage.dart';

/// Provider du service de stockage des projets.
/// Il est créé une seule fois et partagé.
final projectStorageProvider = Provider<ProjectStorage>((ref) {
  return ProjectStorage();
});

/// Provider de la liste des métadonnées des projets locaux.
/// Charge la liste depuis le stockage et la met à jour après chaque opération.
final projectListProvider = FutureProvider<List<ProjectMetadata>>((ref) async {
  final storage = ref.watch(projectStorageProvider);
  return storage.getAllProjects();
});

/// Provider du projet actuellement actif (ouvert dans l'éditeur).
/// Peut être `null` si aucun projet n'est ouvert.
final activeProjectProvider = StateProvider<ProjectModel?>((ref) => null);

/// Provider de chargement d'un projet par son ID.
/// Utilisé pour ouvrir un projet depuis la liste.
final projectByIdProvider = FutureProvider.family<ProjectModel?, String>((ref, projectId) async {
  final storage = ref.watch(projectStorageProvider);
  return storage.loadProject(projectId);
});

/// Action pour créer un nouveau projet.
final createProjectAction = FutureProvider.family<ProjectModel, ({String name, String? description, String? author, String? packageName})>(
  (ref, params) async {
    final storage = ref.watch(projectStorageProvider);
    final project = await storage.createProject(
      name: params.name,
      description: params.description,
      author: params.author,
      packageName: params.packageName,
    );
    // Invalider la liste pour la rafraîchir
    ref.invalidate(projectListProvider);
    return project;
  },
);

/// Action pour sauvegarder le projet actif.
final saveActiveProjectAction = FutureProvider.family<void, ProjectModel>((ref, project) async {
  final storage = ref.watch(projectStorageProvider);
  await storage.saveProject(project);
  // Invalider la liste pour refléter les modifications
  ref.invalidate(projectListProvider);
});

/// Action pour supprimer un projet par son ID.
final deleteProjectAction = FutureProvider.family<void, String>((ref, projectId) async {
  final storage = ref.watch(projectStorageProvider);
  await storage.deleteProject(projectId);
  // Invalider la liste
  ref.invalidate(projectListProvider);
  // Si le projet supprimé est le projet actif, le fermer
  final activeProject = ref.read(activeProjectProvider.notifier).state;
  if (activeProject?.metadata.projectId == projectId) {
    ref.read(activeProjectProvider.notifier).state = null;
  }
});

/// Action pour ouvrir un projet : charge le projet et le définit comme actif.
final openProjectAction = FutureProvider.family<void, String>((ref, projectId) async {
  final storage = ref.watch(projectStorageProvider);
  final project = await storage.loadProject(projectId);
  if (project != null) {
    ref.read(activeProjectProvider.notifier).state = project;
  }
});

/// Action pour fermer le projet actif.
final closeProjectAction = Provider<void Function()>((ref) {
  return () {
    ref.read(activeProjectProvider.notifier).state = null;
  };
});