import 'package:auto_route/auto_route.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/widgets/radio_listview.dart';

@RoutePage(name: 'ServerLocations')
class ServerLocations extends HookConsumerWidget {
  final String? selectedCode;
  final String title;
  final void Function(ServerLocation) onSelected;

  const ServerLocations({
    super.key,
    this.selectedCode,
    required this.title,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = [
      ServerLocation(code: 'BE', label: 'belgium_stghislain'.i18n),
      ServerLocation(code: 'AU', label: 'australia_sydney'.i18n),
      ServerLocation(code: 'BR', label: 'brazil_saopaulo'.i18n),
      // ...
    ];
    final selected = useState<ServerLocation?>(
        locations.firstWhere((l) => selectedCode == l.code));

    return BaseScreen(
      title: title,
      backgroundColor: AppColors.gray1,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'select_private_server_region'.i18n,
                style: AppTestStyles.bodyLarge.copyWith(
                  color: AppColors.logTextColor,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 10),
              child: Text(
                'gcp_location_options'.i18n.fill([locations.length]),
                style: AppTestStyles.bodyMedium.copyWith(
                  color: AppColors.logTextColor,
                  fontWeight: FontWeight.w500,
                  height: 1.43,
                ),
              ),
            ),
            // Locations List
            Expanded(
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppColors.gray2,
                    width: 1,
                  ),
                ),
                child: RadioListView<ServerLocation>(
                  items: locations,
                  groupValue: selected.value,
                  onChanged: (value) {
                    selected.value = value;
                    onSelected(value);
                    Navigator.of(context).pop();
                  },
                  rowBuilder: (loc, sel, onTap) => ServerLocationRow(
                    location: loc,
                    selected: sel,
                    onTap: onTap,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServerLocationRow extends StatelessWidget {
  final ServerLocation location;
  final bool selected;
  final VoidCallback onTap;

  const ServerLocationRow({
    super.key,
    required this.location,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFEDEFEF),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            CountryFlag.fromCountryCode(location.code, width: 24, height: 17),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                location.label,
                style: AppTestStyles.bodyLarge.copyWith(
                  color: AppColors.black1,
                ),
              ),
            ),
            Radio<ServerLocation>(
              value: location,
              groupValue: selected ? location : null,
              onChanged: (_) => onTap(),
              activeColor: AppColors.black1,
            ),
          ],
        ),
      ),
    );
  }
}
