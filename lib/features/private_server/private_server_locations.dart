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

  const PrivateServerLocation({
    super.key,
    required this.location,
    required this.selectedLocation,
    required this.onLocationSelected,
  });

  @override
  ConsumerState<PrivateServerLocation> createState() =>
      _PrivateServerLocationState();
}

class _PrivateServerLocationState extends ConsumerState<PrivateServerLocation> {
  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'private_server_location'.i18n,
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
            'Digital Ocean Location Options (${widget.location.length}) ',
            style: textTheme.labelLarge!.copyWith(
              color: AppColors.gray8,
            ),
          ),
        ),
        Expanded(
            child: AppCard(
          child: ListView(
            padding: EdgeInsets.zero,
            children: widget.location
                .map(
                  (location) => LocationListItem(
                    selectedLocation: selectedLocation.value,
                    location: location,
                    onLocationSelected: (p0) {
                      selectedLocation.value = p0;
                      Future.delayed(Duration(milliseconds: 300), () {
                        widget.onLocationSelected(p0);
                        appRouter.maybePop(p0);
                      });
                    },
                  ),
                )
                .toList(),
          ),
        )),
        SizedBox(height: 16),
        DividerSpace(),
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
            height: 20,
            width: 30,
            shape: RoundedRectangle(5.0),
          ),
          label: location.locationName,
          trailing: Radio<String>(
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
