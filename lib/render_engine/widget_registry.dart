import 'widget_builders/scaffold_builder.dart';
import 'widget_builders/container_builder.dart';
import 'widget_builders/text_builder.dart';
import 'widget_builders/row_column_builder.dart';
import 'widget_builders/button_builder.dart';
import 'widget_builders/image_builder.dart';
import 'widget_builders/icon_builder.dart';
import 'widget_builders/textfield_builder.dart';
import 'widget_builders/checkbox_builder.dart';
import 'widget_builders/switch_builder.dart';
import 'widget_builders/slider_builder.dart';
import 'widget_builders/listview_builder.dart';
import 'widget_builders/gridview_builder.dart';
import 'widget_builders/listtile_builder.dart';
import 'widget_builders/appbar_builder.dart';
import 'widget_builders/sizedbox_builder.dart';
import 'widget_builders/padding_builder.dart';
import 'widget_builders/center_builder.dart';

/// Registre des builders de widgets.
/// Associe le nom de type (ex: "Container") à une fonction de construction.
class WidgetRegistry {
  // Le registre sera utilisé par JsonWidgetParser pour construire les widgets.
  // On conserve une map de types supportés pour référence.
  static const Set<String> supportedTypes = {
    'Scaffold', 'Container', 'Text', 'Row', 'Column', 'Button', 'ElevatedButton',
    'TextButton', 'OutlinedButton', 'Image', 'Icon', 'TextField', 'Checkbox',
    'Switch', 'Slider', 'ListView', 'GridView', 'ListTile', 'AppBar',
    'SizedBox', 'Padding', 'Center',
  };

  static bool isSupported(String type) => supportedTypes.contains(type);
}