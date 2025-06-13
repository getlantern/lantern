import 'package:auto_route/annotations.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';

@RoutePage(name: 'PrivateServerLocation')
class PrivateServerLocation extends StatefulHookConsumerWidget {
  const PrivateServerLocation({super.key});

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
            'Digital Ocean Location Options',
            style: textTheme.labelLarge!.copyWith(
              color: AppColors.gray8,
            ),
          ),
        ),
        Expanded(
          child: AppCard(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                LocationListItem(),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        DividerSpace(),
        SizedBox(height: 16),
        PrimaryButton(
          label: "Set Up Private Server",
          onPressed: () {},
        ),
      ],
    );
  }
}

class LocationListItem extends StatelessWidget {
  const LocationListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTile(
          contentPadding: EdgeInsets.zero,
          icon: CountryFlag.fromCountryCode('ES',
              height: 20, width: 30, shape: RoundedRectangle(5.0)),
          label: 'Australia - Sydney',
          trailing: Radio(
            value: true,
            groupValue: true,
            onChanged: (value) {},
          ),
        ),
        DividerSpace(padding: EdgeInsets.zero),
      ],
    );D}
}
