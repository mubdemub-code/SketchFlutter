import 'package:flutter/material.dart';

/// Sélecteur d'icône Material.
///
/// Affiche l'icône actuelle et permet d'ouvrir une boîte de dialogue
/// pour choisir parmi une grille d'icônes Material avec recherche.
///
/// L'icône est stockée sous forme de chaîne de caractères (nom de la constante
/// Material, ex: "home", "favorite", etc.). Cette chaîne est utilisée dans le JSON
/// du projet et convertie en [IconData] lors du rendu.
class IconPicker extends StatefulWidget {
  /// Nom de l'icône initiale (ex: "home").
  final String initialIconName;

  /// Callback appelé lorsque l'icône change, avec le nouveau nom.
  final ValueChanged<String> onIconChanged;

  /// Libellé optionnel affiché au-dessus du champ.
  final String? label;

  const IconPicker({
    super.key,
    required this.initialIconName,
    required this.onIconChanged,
    this.label,
  });

  @override
  State<IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<IconPicker> {
  late String _iconName;

  @override
  void initState() {
    super.initState();
    _iconName = widget.initialIconName;
  }

  @override
  void didUpdateWidget(IconPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIconName != widget.initialIconName) {
      _iconName = widget.initialIconName;
    }
  }

  IconData get _iconData => kMaterialIcons[_iconName] ?? Icons.circle;

  Future<void> _openPickerDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _IconPickerDialog(initialIconName: _iconName),
    );
    if (selected != null && selected != _iconName) {
      setState(() => _iconName = selected);
      widget.onIconChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              widget.label!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        InkWell(
          onTap: _openPickerDialog,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(_iconData, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _iconName,
                    style: const TextStyle(fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Boîte de dialogue de sélection d'icône.
///
/// Contient une barre de recherche et une grille d'icônes filtrables.
class _IconPickerDialog extends StatefulWidget {
  final String initialIconName;

  const _IconPickerDialog({required this.initialIconName});

  @override
  State<_IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<_IconPickerDialog> {
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MapEntry<String, IconData>> get _filteredIcons {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return kMaterialIcons.entries.toList();
    }
    return kMaterialIcons.entries
        .where((entry) => entry.key.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final icons = _filteredIcons;
    return AlertDialog(
      title: const Text('Choisir une icône'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: icons.isEmpty
                  ? const Center(child: Text('Aucune icône trouvée'))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: icons.length,
                      itemBuilder: (context, index) {
                        final entry = icons[index];
                        final isSelected = entry.key == widget.initialIconName;
                        return InkWell(
                          onTap: () => Navigator.of(context).pop(entry.key),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(entry.value, size: 32),
                                const SizedBox(height: 4),
                                Text(
                                  entry.key,
                                  style: const TextStyle(fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}

/// Map des icônes Material disponibles pour la sélection.
///
/// Contient un sous-ensemble d'icônes couramment utilisées. Cette map peut
/// être étendue facilement. Les clés sont les noms des icônes, les valeurs
/// les [IconData] correspondants.
const Map<String, IconData> kMaterialIcons = {
  'home': Icons.home,
  'favorite': Icons.favorite,
  'star': Icons.star,
  'person': Icons.person,
  'settings': Icons.settings,
  'search': Icons.search,
  'add': Icons.add,
  'delete': Icons.delete,
  'edit': Icons.edit,
  'check': Icons.check,
  'close': Icons.close,
  'arrow_back': Icons.arrow_back,
  'arrow_forward': Icons.arrow_forward,
  'menu': Icons.menu,
  'more_vert': Icons.more_vert,
  'share': Icons.share,
  'download': Icons.download,
  'upload': Icons.upload,
  'refresh': Icons.refresh,
  'info': Icons.info,
  'warning': Icons.warning,
  'error': Icons.error,
  'help': Icons.help,
  'notifications': Icons.notifications,
  'email': Icons.email,
  'phone': Icons.phone,
  'camera': Icons.camera,
  'image': Icons.image,
  'play_arrow': Icons.play_arrow,
  'pause': Icons.pause,
  'stop': Icons.stop,
  'volume_up': Icons.volume_up,
  'volume_down': Icons.volume_down,
  'volume_off': Icons.volume_off,
  'bluetooth': Icons.bluetooth,
  'wifi': Icons.wifi,
  'battery_full': Icons.battery_full,
  'battery_charging_full': Icons.battery_charging_full,
  'cloud': Icons.cloud,
  'cloud_upload': Icons.cloud_upload,
  'cloud_download': Icons.cloud_download,
  'lock': Icons.lock,
  'lock_open': Icons.lock_open,
  'visibility': Icons.visibility,
  'visibility_off': Icons.visibility_off,
  'shopping_cart': Icons.shopping_cart,
  'credit_card': Icons.credit_card,
  'calendar_today': Icons.calendar_today,
  'date_range': Icons.date_range,
  'access_time': Icons.access_time,
  'location_on': Icons.location_on,
  'map': Icons.map,
  'directions': Icons.directions,
  'public': Icons.public,
  'language': Icons.language,
  'account_balance': Icons.account_balance,
  'work': Icons.work,
  'school': Icons.school,
  'fitness_center': Icons.fitness_center,
  'restaurant': Icons.restaurant,
  'local_gas_station': Icons.local_gas_station,
  'local_hospital': Icons.local_hospital,
  'local_pharmacy': Icons.local_pharmacy,
  'local_parking': Icons.local_parking,
  'local_grocery_store': Icons.local_grocery_store,
  'flight': Icons.flight,
  'directions_car': Icons.directions_car,
  'directions_bus': Icons.directions_bus,
  'directions_bike': Icons.directions_bike,
  'train': Icons.train,
  'hotel': Icons.hotel,
  'bed': Icons.bed,
  'pets': Icons.pets,
  'music_note': Icons.music_note,
  'mic': Icons.mic,
  'videocam': Icons.videocam,
  'photo_camera': Icons.photo_camera,
  'filter': Icons.filter,
  'sort': Icons.sort,
  'format_list_bulleted': Icons.format_list_bulleted,
  'format_list_numbered': Icons.format_list_numbered,
  'grid_on': Icons.grid_on,
  'view_list': Icons.view_list,
  'view_module': Icons.view_module,
  'dashboard': Icons.dashboard,
  'table_chart': Icons.table_chart,
  'insert_chart': Icons.insert_chart,
  'pie_chart': Icons.pie_chart,
  'bar_chart': Icons.bar_chart,
  'line_style': Icons.line_style,
  'timeline': Icons.timeline,
  'trending_up': Icons.trending_up,
  'trending_down': Icons.trending_down,
  'attach_money': Icons.attach_money,
  'euro': Icons.euro,
  'payments': Icons.payments,
  'receipt': Icons.receipt,
  'savings': Icons.savings,
  'account_balance_wallet': Icons.account_balance_wallet,
  'contact_phone': Icons.contact_phone,
  'contact_mail': Icons.contact_mail,
  'group': Icons.group,
  'group_add': Icons.group_add,
  'person_add': Icons.person_add,
  'person_remove': Icons.person_remove,
  'verified_user': Icons.verified_user,
  'admin_panel_settings': Icons.admin_panel_settings,
  'security': Icons.security,
  'gavel': Icons.gavel,
  'policy': Icons.policy,
  'privacy_tip': Icons.privacy_tip,
  'lock_clock': Icons.lock_clock,
  'fingerprint': Icons.fingerprint,
  'face': Icons.face,
  'smart_toy': Icons.smart_toy,
  'android': Icons.android,
  'apple': Icons.apple,
  'computer': Icons.computer,
  'laptop': Icons.laptop,
  'smartphone': Icons.smartphone,
  'tablet': Icons.tablet,
  'watch': Icons.watch,
  'keyboard': Icons.keyboard,
  'mouse': Icons.mouse,
  'gamepad': Icons.gamepad,
  'cable': Icons.cable,
  'router': Icons.router,
  'memory': Icons.memory,
  'developer_mode': Icons.developer_mode,
  'code': Icons.code,
  'data_object': Icons.data_object,
  'bug_report': Icons.bug_report,
  'build': Icons.build,
  'construction': Icons.construction,
  'handyman': Icons.handyman,
  'science': Icons.science,
  'biotech': Icons.biotech,
  'calculate': Icons.calculate,
  'functions': Icons.functions,
  'square_foot': Icons.square_foot,
  'architecture': Icons.architecture,
  'design_services': Icons.design_services,
  'draw': Icons.draw,
  'brush': Icons.brush,
  'color_lens': Icons.color_lens,
  'format_paint': Icons.format_paint,
  'palette': Icons.palette,
};