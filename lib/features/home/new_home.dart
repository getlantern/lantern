import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/widgets/vpn_status_indicator.dart';
import 'package:lantern/features/vpn/vpn_switch.dart';

import '../../core/common/common.dart';

@RoutePage(name: 'NewHome')
class NewHome extends StatefulWidget {
  const NewHome({super.key});

  @override
  State<NewHome> createState() => _NewHomeState();
}

class _NewHomeState extends State<NewHome> {
  TextTheme? textTheme;

  @override
  Widget build(BuildContext context) {
    textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
          title: const LanternLogo(),
          leading: IconButton(
              onPressed: () {
                appRouter.push(const Setting());
              },
              icon: const AppImage(path: AppImagePaths.menu))),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: defaultSize),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _buildProBanner(),
          VPNSwitch(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DataUsage(),
              SizedBox(height: 8),
              _buildSetting(),
              SizedBox(height: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProBanner() {
    return Container(
      padding: EdgeInsets.all(defaultSize),
      decoration: BoxDecoration(
          color: AppColors.yellow1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.yellow4, width: 1)),
      child: Column(
        children: [
          Text(
            "Get unlimited data, no ads, and faster speeds!",
            style: textTheme!.labelLarge!.copyWith(
              color: AppColors.gray9,
            ),
          ),
          SizedBox(height: 8),
          ProButton(
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSmartLocation() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox(
              width: 24,
              child: AppImage(path: AppImagePaths.location),
            ),
            SizedBox(width: 8),
            Text('smart_location'.i18n,
                style: textTheme!.labelLarge!.copyWith(color: AppColors.gray7)),
          ],
        ),
        Row(
          children: [
            SizedBox(width: 32.0),
            Text("Fastest Country",
                style:
                    textTheme!.titleMedium!.copyWith(color: AppColors.gray9)),
            Spacer(),
            AppImage(path: AppImagePaths.blot),
            SizedBox(width: 8),
            IconButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: AppImage(path: AppImagePaths.verticalDots),
              padding: EdgeInsets.zero,
              // iconSize: 10,
              constraints: BoxConstraints(),
              visualDensity: VisualDensity.compact,
            )
          ],
        ),
      ],
    );
  }

  Widget _buildSetting() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(defaultSize),
        child: Column(
          children: [
            _buildVPNStatusRow(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: DividerSpace(),
            ),
            _buildSmartLocation(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: DividerSpace(),
            ),
            _buildSpiltTunneling(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpiltTunneling() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox(
              width: 24,
              child: AppImage(path: AppImagePaths.callSpilt),
            ),
            SizedBox(width: 8),
            Text('split_tunneling'.i18n,
                style: textTheme!.labelLarge!.copyWith(color: AppColors.gray7)),
          ],
        ),
        Row(
          children: [
            SizedBox(width: 32.0),
            Text("Enabled",
                style:
                    textTheme!.titleMedium!.copyWith(color: AppColors.gray9)),
            Spacer(),
            IconButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: AppImage(path: AppImagePaths.verticalDots),
              padding: EdgeInsets.zero,
              // iconSize: 10,
              constraints: BoxConstraints(),
              visualDensity: VisualDensity.compact,
            )
          ],
        ),
      ],
    );
  }

  Widget _buildVPNStatusRow() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox(
              width: 24,
              child: AppImage(path: AppImagePaths.glob),
            ),
            SizedBox(width: 8),
            Text('vpn_status'.i18n,
                style: textTheme!.labelLarge!.copyWith(color: AppColors.gray7)),
          ],
        ),
        Row(
          children: [
            SizedBox(width: 32.0),
            Text(VPNStatus.disconnected.name.capitalize,
                style:
                    textTheme!.titleMedium!.copyWith(color: AppColors.gray9)),
            Spacer(),
            VPNStatusIndicator(status: VPNStatus.disconnected),
          ],
        ),
      ],
    );
  }
}
