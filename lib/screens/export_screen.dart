import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../models/generation_settings.dart';
import '../models/project_model.dart';
import '../providers/project_provider.dart';
import '../services/compile_service.dart';
import '../services/file_download_service.dart';
import '../services/github_service.dart';
import '../widgets/dropdown_input.dart';
import '../widgets/icon_picker.dart';

/// Écran d'export et de compilation de l'application.
///
/// Permet de configurer les paramètres de génération (nom de package, version,
/// orientation, icône), de se connecter à GitHub (pour la compilation décentralisée),
/// puis de lancer la compilation. Une barre de progression indique l'état.
/// Une fois l'APK généré, l'utilisateur peut le télécharger (si pas déjà fait)
/// ou le partager.
///
/// L'écran utilise le provider [activeProjectProvider] pour obtenir le projet
/// actuellement ouvert. Il crée un [GitHubService] avec le token saisi et un
/// [GitHubCompilationBackend] pour la compilation.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  // Contrôleurs de formulaire
  final _packageNameController = TextEditingController();
  final _versionController = TextEditingController();
  final _githubTokenController = TextEditingController();

  // État local
  AppOrientation _orientation = AppOrientation.portrait;
  String _iconName = 'home'; // icône par défaut
  bool _isConnected = false;
  bool _isCompiling = false;
  String _progressMessage = '';
  String? _apkFilePath;
  String? _errorMessage;

  // Services
  GitHubService? _githubService;
  GitHubCompilationBackend? _backend;
  CompileService? _compileService;
  final FileDownloadService _fileDownloadService = FileDownloadService();

  @override
  void initState() {
    super.initState();
    // Pré-remplir avec les paramètres du projet actif.
    final project = ref.read(activeProjectProvider);
    if (project != null) {
      _packageNameController.text = project.generationSettings.packageName;
      _versionController.text = project.generationSettings.version;
      _orientation = project.generationSettings.orientation;
      if (project.generationSettings.iconAssetId != null) {
        _iconName = project.generationSettings.iconAssetId!;
      }
    }
  }

  @override
  void dispose() {
    _packageNameController.dispose();
    _versionController.dispose();
    _githubTokenController.dispose();
    super.dispose();
  }

  /// Tente de se connecter à GitHub avec le token fourni.
  Future<void> _connectToGithub() async {
    final token = _githubTokenController.text.trim();
    if (token.isEmpty) {
      _showError('Veuillez saisir un token GitHub.');
      return;
    }

    setState(() {
      _isCompiling = false;
      _errorMessage = null;
      _progressMessage = 'Connexion à GitHub...';
    });

    try {
      final github = GitHubService(token: token);
      final user = await github.getAuthenticatedUser();
      setState(() {
        _githubService = github;
        _isConnected = true;
        _progressMessage = 'Connecté en tant que ${user['login']}';
      });
      _showSuccess('Connecté à GitHub avec succès.');
    } catch (e) {
      setState(() {
        _isConnected = false;
        _progressMessage = '';
      });
      _showError('Échec de connexion : $e');
    }
  }

  /// Lance la compilation du projet.
  Future<void> _compile() async {
    final project = ref.read(activeProjectProvider);
    if (project == null) {
      _showError('Aucun projet actif.');
      return;
    }

    if (!_isConnected) {
      _showError('Veuillez vous connecter à GitHub avant de compiler.');
      return;
    }

    // Mettre à jour les paramètres de génération dans le projet.
    final updatedSettings = project.generationSettings.copyWith(
      packageName: _packageNameController.text.trim(),
      version: _versionController.text.trim(),
      orientation: _orientation,
      iconAssetId: _iconName,
    );
    final updatedProject = project.copyWith(generationSettings: updatedSettings);
    ref.read(activeProjectProvider.notifier).state = updatedProject;

    // Créer le backend si non déjà fait.
    _backend ??= GitHubCompilationBackend(
      githubService: _githubService!,
      cleanupAfterCompile: false, // Garder le dépôt pour le debug pour l'instant
    );

    // Créer un générateur de code simple (à remplacer par le vrai générateur).
    final codeGenerator = _SimpleCodeGenerator();
    _compileService ??= CompileService(
      backend: _backend!,
      codeGenerator: codeGenerator,
    );

    setState(() {
      _isCompiling = true;
      _errorMessage = null;
      _apkFilePath = null;
      _progressMessage = 'Préparation de la compilation...';
    });

    try {
      final result = await _compileService!.compile(updatedProject);
      if (result.success) {
        setState(() {
          _isCompiling = false;
          _apkFilePath = result.apkFilePath;
          _progressMessage = 'Compilation réussie !';
        });
        _showSuccess('Compilation terminée. APK disponible.');
      } else {
        setState(() {
          _isCompiling = false;
          _errorMessage = result.message;
          _progressMessage = '';
        });
        _showError('Échec de la compilation : ${result.message}');
      }
    } catch (e) {
      setState(() {
        _isCompiling = false;
        _errorMessage = e.toString();
        _progressMessage = '';
      });
      _showError('Erreur inattendue : $e');
    }
  }

  /// Télécharge l'APK (dans le cas où il n'est pas déjà local).
  Future<void> _downloadApk() async {
    if (_apkFilePath != null) {
      // Déjà téléchargé, on peut ouvrir ou partager.
      // Pour l'instant, on affiche le chemin.
      _showSuccess('APK disponible : $_apkFilePath');
      return;
    }
    // Simule un téléchargement (à implémenter avec l'URL de l'artifact).
    _showError('Téléchargement manuel non implémenté. Utilisez la compilation.');
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surface : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.exportTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section Connexion GitHub
          _buildSectionCard(
            context,
            title: 'Connexion GitHub',
            icon: Icons.link,
            cardColor: cardColor,
            child: _isConnected
                ? Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Connecté')),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isConnected = false;
                            _githubService = null;
                            _backend = null;
                            _compileService = null;
                            _githubTokenController.clear();
                          });
                        },
                        child: const Text('Déconnecter'),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _githubTokenController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Token GitHub',
                          hintText: 'ghp_...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.vpn_key),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _connectToGithub,
                        icon: const Icon(Icons.login),
                        label: const Text('Se connecter'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // Section Paramètres de génération
          _buildSectionCard(
            context,
            title: 'Paramètres de génération',
            icon: Icons.build,
            cardColor: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _packageNameController,
                  decoration: InputDecoration(
                    labelText: AppStrings.packageName,
                    hintText: 'com.monapp.app',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.branding_watermark),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _versionController,
                  decoration: InputDecoration(
                    labelText: AppStrings.version,
                    hintText: '1.0.0',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.tag),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownInput<AppOrientation>.simple(
                  label: AppStrings.orientation,
                  value: _orientation,
                  options: AppOrientation.values,
                  labelFor: (o) => o.displayName,
                  onChanged: (newValue) {
                    setState(() {
                      _orientation = newValue ?? AppOrientation.portrait;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Sélecteur d'icône
                IconPicker(
                  label: AppStrings.iconApp,
                  initialIconName: _iconName,
                  onIconChanged: (newIcon) {
                    setState(() {
                      _iconName = newIcon;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bouton de compilation
          FilledButton.icon(
            onPressed: _isCompiling ? null : _compile,
            icon: _isCompiling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload),
            label: Text(_isCompiling ? 'Compilation en cours...' : 'Compiler'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          // Zone de progression
          if (_isCompiling || _progressMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isCompiling)
                      const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      _progressMessage,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Erreur éventuelle
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.error.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Bouton de téléchargement si APK disponible
          if (_apkFilePath != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _downloadApk,
              icon: const Icon(Icons.download),
              label: const Text(AppStrings.downloadApk),
            ),
          ],
        ],
      ),
    );
  }

  /// Construit une carte de section avec titre et icône.
  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color cardColor,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Générateur de code simple et temporaire.
///
/// Remplace le générateur complet en attendant son implémentation.
/// Génère un projet Flutter minimal qui utilise le code Dart du projet.
class _SimpleCodeGenerator implements IProjectCodeGenerator {
  @override
  Map<String, String> generate(ProjectModel project) {
    // Utilisation basique : nous allons créer un main.dart simple avec
    // un affichage de texte, et le pubspec.yaml.
    final mainDart = '''
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${project.metadata.name}',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(title: Text('${project.metadata.name}')),
        body: Center(child: Text('Application générée par SketchFlutter')),
      ),
    );
  }
}
''';
    final pubspec = '''
name: ${project.metadata.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_')}
description: ${project.metadata.description ?? ''}
version: ${project.generationSettings.version}
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
''';
    return {
      'lib/main.dart': mainDart,
      'pubspec.yaml': pubspec,
    };
  }
}