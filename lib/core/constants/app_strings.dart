/// Textes et libellés de l'application SketchFlutter.
///
/// Centralise toutes les chaînes de caractères utilisées dans l'interface
/// utilisateur pour faciliter la maintenance et l'internationalisation future.
class AppStrings {
  AppStrings._(); // Classe non instanciable

  // ---------------------------------------------------------------------------
  // Informations générales
  // ---------------------------------------------------------------------------

  /// Nom de l'application.
  static const String appName = 'SketchFlutter';

  /// Slogan ou description courte.
  static const String appSlogan = 'Créez des apps Flutter visuellement';

  /// Version de l'application.
  static const String appVersion = '1.0.0';

  // ---------------------------------------------------------------------------
  // Écran d'accueil
  // ---------------------------------------------------------------------------

  static const String homeTitle = 'Mes Projets';
  static const String homeSubtitle = 'Gérez vos applications';
  static const String newProject = 'Nouveau Projet';
  static const String noProjects = 'Aucun projet pour le moment';
  static const String noProjectsSubtitle = 'Appuyez sur le bouton + pour créer votre premier projet';
  static const String deleteProject = 'Supprimer le projet';
  static const String deleteProjectConfirm = 'Voulez-vous vraiment supprimer ce projet ?';
  static const String renameProject = 'Renommer';
  static const String duplicateProject = 'Dupliquer';
  static const String exportProject = 'Exporter (.mub)';
  static const String importProject = 'Importer (.mub)';
  static const String projectName = 'Nom du projet';
  static const String projectDescription = 'Description';
  static const String lastModified = 'Modifié le';
  static const String searchProjects = 'Rechercher...';
  static const String sortBy = 'Trier par';
  static const String sortByName = 'Nom';
  static const String sortByDate = 'Date';

  // ---------------------------------------------------------------------------
  // Éditeur - Général
  // ---------------------------------------------------------------------------

  static const String editorTitle = 'Éditeur';
  static const String undo = 'Annuler';
  static const String redo = 'Rétablir';
  static const String preview = 'Aperçu';
  static const String export = 'Exporter';
  static const String save = 'Enregistrer';
  static const String saving = 'Enregistrement...';
  static const String saved = 'Projet enregistré';
  static const String autoSave = 'Sauvegarde automatique';

  // ---------------------------------------------------------------------------
  // Onglets de l'éditeur
  // ---------------------------------------------------------------------------

  static const String tabDesign = 'Design';
  static const String tabLogic = 'Logique';
  static const String tabPages = 'Pages';

  // ---------------------------------------------------------------------------
  // Onglet Design
  // ---------------------------------------------------------------------------

  static const String palette = 'Widgets';
  static const String inspector = 'Propriétés';
  static const String widgetTree = 'Arborescence';
  static const String addWidget = 'Ajouter un widget';
  static const String removeWidget = 'Supprimer le widget';
  static const String duplicateWidget = 'Dupliquer';
  static const String moveUp = 'Monter';
  static const String moveDown = 'Descendre';
  static const String emptyCanvas = 'Glissez un widget ici';
  static const String selectWidget = 'Sélectionnez un widget';
  static const String searchWidgets = 'Rechercher un widget...';

  // Catégories de widgets
  static const String categoryLayout = 'Mise en page';
  static const String categoryBasic = 'Basiques';
  static const String categoryList = 'Listes';
  static const String categoryForm = 'Formulaires';
  static const String categoryNavigation = 'Navigation';
  static const String categoryFeedback = 'Feedback';
  static const String categoryAll = 'Tous';

  // ---------------------------------------------------------------------------
  // Inspecteur de propriétés
  // ---------------------------------------------------------------------------

  static const String propertyText = 'Texte';
  static const String propertyColor = 'Couleur';
  static const String propertyBackgroundColor = 'Fond';
  static const String propertyFontSize = 'Taille du texte';
  static const String propertyFontWeight = 'Poids de la police';
  static const String propertyFontStyle = 'Style';
  static const String propertyTextAlign = 'Alignement du texte';
  static const String propertyWidth = 'Largeur';
  static const String propertyHeight = 'Hauteur';
  static const String propertyPadding = 'Padding';
  static const String propertyMargin = 'Marge';
  static const String propertyAlignment = 'Alignement';
  static const String propertyBorderRadius = 'Rayon de bordure';
  static const String propertyBorder = 'Bordure';
  static const String propertyMainAxisAlignment = 'Alignement principal';
  static const String propertyCrossAxisAlignment = 'Alignement secondaire';
  static const String propertySpacing = 'Espacement';
  static const String propertyRunSpacing = 'Espacement des lignes';
  static const String propertyFlex = 'Flex';
  static const String propertyHint = 'Indice';
  static const String propertyObscureText = 'Masquer le texte';
  static const String propertyKeyboardType = 'Type de clavier';
  static const String propertyMaxLines = 'Lignes max';
  static const String propertyValue = 'Valeur';
  static const String propertyMin = 'Min';
  static const String propertyMax = 'Max';
  static const String propertyItems = 'Éléments';
  static const String propertyScrollDirection = 'Direction de défilement';
  static const String propertyReverse = 'Inverser';
  static const String propertyFit = 'Ajustement';
  static const String propertySrc = 'Source';
  static const String propertyIcon = 'Icône';
  static const String propertyButtonType = 'Type de bouton';
  static const String propertyOnPressed = 'Événement onPressed';
  static const String propertyOnTap = 'Événement onTap';
  static const String propertyOnChanged = 'Événement onChanged';
  static const String propertyOnLongPress = 'Événement onLongPress';

  // Valeurs d'énumération
  static const String valueCenter = 'Centre';
  static const String valueTopLeft = 'Haut gauche';
  static const String valueTopCenter = 'Haut centre';
  static const String valueTopRight = 'Haut droite';
  static const String valueCenterLeft = 'Centre gauche';
  static const String valueCenterRight = 'Centre droite';
  static const String valueBottomLeft = 'Bas gauche';
  static const String valueBottomCenter = 'Bas centre';
  static const String valueBottomRight = 'Bas droite';
  static const String valueStart = 'Début';
  static const String valueEnd = 'Fin';
  static const String valueSpaceBetween = 'Espace entre';
  static const String valueSpaceAround = 'Espace autour';
  static const String valueSpaceEvenly = 'Espace uniforme';
  static const String valueMax = 'Max';
  static const String valueMin = 'Min';
  static const String valueVertical = 'Vertical';
  static const String valueHorizontal = 'Horizontal';
  static const String valueCover = 'Couvrir';
  static const String valueContain = 'Contenir';
  static const String valueFill = 'Remplir';
  static const String valueNone = 'Aucun';
  static const String valueScaleDown = 'Réduire';
  static const String valueElevated = 'Surélevé';
  static const String valueText = 'Texte';
  static const String valueOutlined = 'Contour';
  static const String valueLeft = 'Gauche';
  static const String valueRight = 'Droite';
  static const String valueJustify = 'Justifier';
  static const String valueNormal = 'Normal';
  static const String valueBold = 'Gras';
  static const String valueItalic = 'Italique';
  static const String valueUnderline = 'Souligné';
  static const String valueLineThrough = 'Barré';
  static const String valueOverline = 'Surligné';

  // ---------------------------------------------------------------------------
  // Onglet Logique
  // ---------------------------------------------------------------------------

  static const String logicTitle = 'Logique';
  static const String events = 'Événements';
  static const String addEvent = 'Ajouter un événement';
  static const String noEvents = 'Aucun événement';
  static const String noEventsSubtitle = 'Sélectionnez un widget interactif pour ajouter de la logique';
  static const String blocks = 'Blocs';
  static const String addBlock = 'Ajouter un bloc';
  static const String blockIf = 'Si... Alors';
  static const String blockLoop = 'Boucle';
  static const String blockSetVariable = 'Définir variable';
  static const String blockShowSnackbar = 'Afficher message';
  static const String blockNavigate = 'Naviguer vers';
  static const String blockCallApi = 'Appeler API';
  static const String blockMathOperation = 'Opération mathématique';
  static const String blockCondition = 'Condition';
  static const String blockVariable = 'Variable';
  static const String blockLiteral = 'Valeur';
  static const String blockOperator = 'Opérateur';
  static const String blockThen = 'Alors';
  static const String blockElse = 'Sinon';
  static const String blockAddVariable = 'Ajouter une variable';
  static const String blockVariableName = 'Nom de la variable';
  static const String blockVariableType = 'Type';
  static const String blockVariableInitialValue = 'Valeur initiale';
  static const String blockVariablePersistent = 'Persistante';
  static const String testLogic = 'Tester la logique';
  static const String variableManager = 'Variables globales';
  static const String noVariables = 'Aucune variable';

  // ---------------------------------------------------------------------------
  // Onglet Pages
  // ---------------------------------------------------------------------------

  static const String pagesTitle = 'Pages';
  static const String addPage = 'Ajouter une page';
  static const String pageName = 'Nom de la page';
  static const String initialPage = 'Page d\'accueil';
  static const String setAsInitial = 'Définir comme page initiale';
  static const String pageTransition = 'Transition';
  static const String pageRoute = 'Route';

  // ---------------------------------------------------------------------------
  // Mode Aperçu
  // ---------------------------------------------------------------------------

  static const String previewTitle = 'Aperçu';
  static const String exitPreview = 'Quitter l\'aperçu';
  static const String reloadPreview = 'Recharger';
  static const String previewConsole = 'Console';
  static const String previewError = 'Erreur d\'exécution';

  // ---------------------------------------------------------------------------
  // Export et Compilation
  // ---------------------------------------------------------------------------

  static const String exportTitle = 'Exporter l\'application';
  static const String compile = 'Compiler';
  static const String compiling = 'Compilation en cours...';
  static const String compileSuccess = 'Compilation réussie !';
  static const String compileError = 'Erreur de compilation';
  static const String downloadApk = 'Télécharger l\'APK';
  static const String packageName = 'Nom du package';
  static const String version = 'Version';
  static const String iconApp = 'Icône de l\'application';
  static const String permissions = 'Permissions Android';
  static const String orientation = 'Orientation';
  static const String portrait = 'Portrait';
  static const String landscape = 'Paysage';
  static const String connectGithub = 'Connecter GitHub';
  static const String githubConnected = 'GitHub connecté';
  static const String buildQueue = 'File d\'attente de compilation';
  static const String buildInProgress = 'Compilation en cours';
  static const String buildWaiting = 'En attente';
  static const String buildCompleted = 'Terminé';
  static const String buildFailed = 'Échoué';

  // ---------------------------------------------------------------------------
  // Paramètres
  // ---------------------------------------------------------------------------

  static const String settingsTitle = 'Paramètres';
  static const String darkMode = 'Mode sombre';
  static const String language = 'Langue';
  static const String autosave = 'Sauvegarde automatique';
  static const String about = 'À propos';
  static const String privacyPolicy = 'Politique de confidentialité';
  static const String termsOfService = 'Conditions d\'utilisation';
  static const String versionLabel = 'Version';

  // ---------------------------------------------------------------------------
  // Messages d'erreur et de confirmation
  // ---------------------------------------------------------------------------

  static const String error = 'Erreur';
  static const String warning = 'Attention';
  static const String success = 'Succès';
  static const String info = 'Information';
  static const String confirm = 'Confirmer';
  static const String cancel = 'Annuler';
  static const String ok = 'OK';
  static const String close = 'Fermer';
  static const String retry = 'Réessayer';
  static const String yes = 'Oui';
  static const String no = 'Non';

  static const String errorInvalidJson = 'Format JSON invalide';
  static const String errorProjectNotFound = 'Projet introuvable';
  static const String errorSaveFailed = 'Échec de la sauvegarde';
  static const String errorLoadFailed = 'Échec du chargement';
  static const String errorImportFailed = 'Importation échouée';
  static const String errorExportFailed = 'Exportation échouée';
  static const String errorCompileFailed = 'Compilation échouée';
  static const String errorNetwork = 'Erreur réseau';
  static const String errorUnknown = 'Erreur inconnue';

  // ---------------------------------------------------------------------------
  // Messages spécifiques à l'import/export .mub
  // ---------------------------------------------------------------------------

  static const String importSuccess = 'Projet importé avec succès';
  static const String exportSuccess = 'Projet exporté avec succès';
  static const String importTitle = 'Importer un projet';
  static const String exportTitleShort = 'Exporter';
  static const String fileExtension = 'Fichier .mub';
  static const String chooseFile = 'Choisir un fichier';
  static const String invalidFile = 'Fichier invalide';
  static const String unsupportedVersion = 'Version de schéma non supportée';
}