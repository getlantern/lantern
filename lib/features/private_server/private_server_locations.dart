import 'package:auto_route/annotations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';

@RoutePage(name: 'PrivateServerLocation')
class PrivateServerLocation extends StatefulHookConsumerWidget {
  final List<String> location;
  final String? selectedLocation;
  final Function(String) onLocationSelected;
  final CloudProvider provider;

  const PrivateServerLocation({
    super.key,
    required this.location,
    required this.selectedLocation,
    required this.onLocationSelected,
    required this.provider,
  });

  @override
  ConsumerState<PrivateServerLocation> createState() =>
      _PrivateServerLocationState();
}

class _PrivateServerLocationState extends ConsumerState<PrivateServerLocation> {
  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: widget.provider == CloudProvider.digitalOcean
          ? 'do_private_server_location'.i18n
          : 'gcp_private_server_location'.i18n,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final textTheme = Theme.of(context).textTheme;
    final selectedLocation = useState<String?>(widget.selectedLocation ?? '');
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('private_server_note'.i18n, style: textTheme.bodyLarge),
        ),
        SizedBox(height: 16),
        DividerSpace(),
        SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${widget.provider.displayName} Location Options (${widget.location.length}) ',
            style: textTheme.labelLarge!.copyWith(
              color: AppColors.gray8,
            ),
          ),
        ),
        Expanded(
            child: AppCard(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: widget.location.length,
            itemBuilder: (context, index) {
              final item = widget.location[index];
              return KeyedSubtree(
                key: Key('psl.location.$index'),
                child: LocationListItem(
                  selectedLocation: selectedLocation.value,
                  location: item,
                  onLocationSelected: (p0) {
                    selectedLocation.value = p0;
                    Future.delayed(Duration(milliseconds: 300), () {
                      widget.onLocationSelected(p0);
                      appRouter.maybePop(p0);
                    });
                  },
                ),
              );
            },
          ),
        )),
        SizedBox(height: 16),
      ],
    );
  }
}

class LocationListItem extends StatelessWidget {
  final String location;
  final String? selectedLocation;
  final Function(String) onLocationSelected;

  const LocationListItem({
    super.key,
    required this.location,
    required this.onLocationSelected,
    this.selectedLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTile(
          onPressed: () {
            onLocationSelected(location);
          },
          contentPadding: EdgeInsets.zero,
          icon: CountryFlag.fromCountryCode(
            location.countryCode,
            theme: const ImageTheme(
              shape: RoundedRectangle(5),
              width: 30,
              height: 20,
            ),
          ),
          label: location.locationName,
          trailing: AppRadioButton<String>(
            value: location,
            groupValue: selectedLocation,
            onChanged: (value) {
              onLocationSelected(location);
            },
          ),
        ),
        DividerSpace(padding: EdgeInsets.zero),
      ],
    );
  }
}
