import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Point d'entrée de l'application SketchFlutter.
///
/// Cette fonction initialise Flutter puis lance le widget racine
/// [SketchFlutterApp] enveloppé dans un [ProviderScope] pour permettre
/// l'utilisation de Riverpod dans toute l'application.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SketchFlutterApp(),
    ),
  );
}