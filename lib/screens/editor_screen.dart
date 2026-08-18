import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../providers/editor_provider.dart';
import '../providers/project_provider.dart';
import '../widgets/debouncer.dart'; // (nous l'avons dans core/utils, mais on peut l'importer)
import 'design_tab.dart';
import 'logic_tab.dart';
import 'pages_tab.dart';

/// Écran principal de l'éditeur de projet.
///
/// Il affiche le projet actif et permet de basculer entre les onglets
/// Design, Logique et Pages grâce à une barre de navigation inférieure.
///
/// L'AppBar contient les actions globales :
///   - Annuler / Rétablir (undo/redo)
///   - Aperçu (mode test local)
///   - Exporter (compilation APK)
///   - Enregistrer (sauvegarde manuelle)
///
/// L'écran écoute le provider [activeProjectProvider]. Si aucun projet n'est
/// ouvert, un message d'erreur ou un état vide est affiché.
///
/// La sauvegarde automatique est gérée par un debounce lors des modifications.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  int _currentIndex = 0;

  // Debouncer pour la sauvegarde automatique.
  final Debouncer _saveDebouncer = Debouncer(delay: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    // Écouter les changements du projet actif pour déclencher la sauvegarde auto.
    // On utilisera ref.listen dans le build, car initState n'a pas accès à ref.
    // Voir plus bas.
  }

  @override
  void dispose() {
    _saveDebouncer.dispose();
    super.dispose();
  }

  /// Sauvegarde manuelle ou automatique du projet actif.
  Future<void> _saveProject() async {
    final project = ref.read(activeProjectProvider);
    if (project == null) return;

    await ref.read(saveActiveProjectAction(project).future).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.saved)),
        );
      }
    }).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de sauvegarde : $e')),
        );
      }
    });
  }

  /// Affiche le dialogue de confirmation avant de quitter l'éditeur.
  Future<bool> _onWillPop() async {
    // Vérifier s'il y a des modifications non sauvegardées (simplifié).
    // Ici, on peut toujours autoriser la sortie, mais on pourrait demander confirmation.
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(activeProjectProvider);

    // Écouter les changements de projet pour déclencher la sauvegarde auto.
    ref.listen<ProjectModel?>(activeProjectProvider, (previous, next) {
      if (previous != next && next != null) {
        // Déclencher le debounce de sauvegarde.
        _saveDebouncer.run(() {
          if (mounted) {
            _saveProject();
          }
        });
      }
    });

    if (projectAsync == null) {
      // Aucun projet ouvert : afficher un message et un bouton retour.
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.editorTitle)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Aucun projet ouvert',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 8),
              Text(
                'Retournez à l\'accueil pour ouvrir un projet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    final project = projectAsync!;
    final editorState = ref.watch(editorProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(project.metadata.name),
        actions: [
          // Bouton Annuler
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: AppStrings.undo,
            onPressed: editorState.canUndo
                ? () => ref.read(editorProvider.notifier).undo()
                : null,
          ),
          // Bouton Rétablir
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: AppStrings.redo,
            onPressed: editorState.canRedo
                ? () => ref.read(editorProvider.notifier).redo()
                : null,
          ),
          // Bouton Aperçu
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: AppStrings.preview,
            onPressed: () {
              // Naviguer vers l'écran d'aperçu (à implémenter).
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PreviewScreen(),
                ),
              );
            },
          ),
          // Bouton Exporter
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: AppStrings.export,
            onPressed: () {
              // Naviguer vers l'écran d'export (à implémenter).
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ExportScreen(),
                ),
              );
            },
          ),
          // Bouton Enregistrer
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: AppStrings.save,
            onPressed: _saveProject,
          ),
        ],
      ),
      body: Column(
        children: [
          // Zone de contenu des onglets.
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                DesignTab(project: project), // Onglet Design
                LogicTab(project: project),  // Onglet Logique
                PagesTab(project: project),  // Onglet Pages
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.design_services_outlined),
            selectedIcon: Icon(Icons.design_services),
            label: AppStrings.tabDesign,
          ),
          NavigationDestination(
            icon: Icon(Icons.code_outlined),
            selectedIcon: Icon(Icons.code),
            label: AppStrings.tabLogic,
          ),
          NavigationDestination(
            icon: Icon(Icons.pages_outlined),
            selectedIcon: Icon(Icons.pages),
            label: AppStrings.tabPages,
          ),
        ],
      ),
    );
  }
}

/// Placeholder pour PreviewScreen (à implémenter dans un fichier séparé).
class PreviewScreen extends StatelessWidget {
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.previewTitle)),
      body: const Center(child: Text('Aperçu en construction')),
    );
  }
}

/// Placeholder pour ExportScreen (à implémenter dans un fichier séparé).
class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.exportTitle)),
      body: const Center(child: Text('Export en construction')),
    );
  }
}