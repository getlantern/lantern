import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/vpn_status_indicator.dart';
import 'package:lantern/features/vpn/server_desktop_view.dart';
import 'package:lantern/features/vpn/server_mobile_view.dart';

typedef OnSeverSelected = Function(String selectedServer);

@RoutePage(name: 'ServerSelection')
class ServerSelection extends StatefulWidget {
  const ServerSelection({super.key});

  @override
  State<ServerSelection> createState() => _ServerSelectionState();
}

class _ServerSelectionState extends State<ServerSelection> {
  TextTheme? _textTheme;

  bool isUserPro = false;

  @override
  Widget build(BuildContext context) {
    _textTheme = Theme.of(context).textTheme;
    return BaseScreen(title: 'server_selection'.i18n, body: _buildBody());
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // _buildSelectedLocation(),
        // DividerSpace(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
        SizedBox(height: 8),
        _buildSmartLocation(),
        SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('automatically_chooses_fastest_location'.i18n,
              style: _textTheme?.bodyMedium!.copyWith(
                color: AppColors.gray8,
              )),
        ),
        DividerSpace(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
        if (!isUserPro)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: ProBanner(),
          ),
        Expanded(
            child: ServerLocationListView(
          userPro: isUserPro,
        )),
      ],
    );
  }

  Widget _buildSmartLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('smart_location'.i18n,
              style: _textTheme?.labelLarge!.copyWith(
                color: AppColors.gray8,
              )),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppTile(
            icon: AppImagePaths.location,
            label: 'Fastest Country',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppImage(path: AppImagePaths.blot),
                Radio<bool>(
                  activeColor: AppColors.gray9,
                  value: true,
                  groupValue: true,
                  onChanged: (value) {},
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('smart_location'.i18n,
              style: _textTheme?.labelLarge!.copyWith(
                color: AppColors.gray8,
              )),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppTile(
            icon: AppImagePaths.location,
            label: 'Fastest Country',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VPNStatusIndicator(status: VPNStatus.disconnected),
                Radio<bool>(
                  activeColor: AppColors.gray9,
                  value: true,
                  groupValue: false,
                  onChanged: (value) {},
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ServerLocationListView extends StatelessWidget {
  final bool userPro;

  const ServerLocationListView({
    super.key,
    required this.userPro,
  });

  @override
  Widget build(BuildContext context) {
    final _textTheme = Theme.of(context).textTheme;
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('pro_locations'.i18n,
                style: _textTheme!.labelLarge!.copyWith(
                  color: AppColors.gray8,
                )),
          ),
        ),
        Positioned(
          top: 26,
          bottom: 0,
          right: 0,
          left: 0,
          child: Column(
            children: [
              Flexible(
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      if (PlatformUtils.isDesktop()) {
                        return ServerDesktopView(
                          onServerSelected: onServerSelected,
                        );
                      }
                      return ServerMobileView(
                        onServerSelected: onServerSelected,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!userPro)
          Container(
            color: AppColors.white.withValues(alpha: 0.5),
          )
      ],
    );
  }

  void onServerSelected(String selectedServer) {}
}
