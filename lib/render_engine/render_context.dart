import '../models/project_model.dart';
import 'property_parsers/color_parser.dart';
import 'property_parsers/edge_insets_parser.dart';
import 'property_parsers/alignment_parser.dart';
import 'property_parsers/text_style_parser.dart';
import 'property_parsers/reference_resolver.dart';

/// Contexte partagé pour le moteur de rendu.
///
/// Regroupe le projet (design system, assets), les parsers, le resolver,
/// et un callback [setVariable] pour mettre à jour les variables globales
/// lors de l'exécution des blocs logiques.
class RenderContext {
  final ProjectModel project;
  final ReferenceResolver resolver;
  late final ColorParser colorParser;
  late final EdgeInsetsParser edgeInsetsParser;
  late final AlignmentParser alignmentParser;
  late final TextStyleParser textStyleParser;

  /// Callback optionnel pour modifier une variable (utilisé par les blocs logiques).
  /// Signature : `void setVariable(String variableId, dynamic value)`.
  final void Function(String, dynamic)? setVariable;

  RenderContext({
    required this.project,
    required Map<String, dynamic> variables,
    this.setVariable,
  }) : resolver = ReferenceResolver(
          designSystem: project.designSystem,
          variables: variables,
        ) {
    colorParser = ColorParser(resolver);
    edgeInsetsParser = EdgeInsetsParser(resolver);
    alignmentParser = const AlignmentParser();
    textStyleParser = TextStyleParser(
      colorParser: colorParser,
      resolver: resolver,
    );
  }
}