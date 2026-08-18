import 'dart:async';

/// Utilitaire de debounce pour retarder l'exécution d'une action.
///
/// Le debounce est utile dans les cas où une action coûteuse ne doit être
/// déclenchée qu'après une période d'inactivité de l'utilisateur. Par exemple :
///   - recherche dans la palette de widgets pendant la frappe,
///   - mise à jour du rendu après modification d'une propriété,
///   - sauvegarde automatique après une série de modifications.
///
/// Exemple d'utilisation :
/// ```dart
/// final Debouncer debouncer = Debouncer(delay: Duration(milliseconds: 300));
/// debouncer.run(() {
///   // Action à exécuter après 300 ms d'inactivité
/// });
/// ```
class Debouncer {
  /// Délai d'attente avant l'exécution de l'action.
  final Duration delay;

  Timer? _timer;

  /// Constructeur.
  ///
  /// [delay] : durée d'attente avant exécution (défaut : 300 ms).
  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// Exécute [action] après le délai configuré.
  ///
  /// Si une action précédente était en attente, elle est annulée et remplacée.
  void run(void Function() action) {
    cancel();
    _timer = Timer(delay, action);
  }

  /// Annule l'action en attente, si elle existe.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Vérifie si une action est en attente.
  bool get isPending => _timer != null && _timer!.isActive;

  /// Exécute [action] immédiatement et annule toute action en attente.
  void flush(void Function() action) {
    cancel();
    action();
  }

  /// Libère les ressources du debouncer.
  void dispose() {
    cancel();
  }
}