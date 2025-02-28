import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/vpn_status_indicator.dart';

@RoutePage(name: 'ServerSelection')
class ServerSelection extends StatefulWidget {
  const ServerSelection({super.key});

  @override
  State<ServerSelection> createState() => _ServerSelectionState();
}

class _ServerSelectionState extends State<ServerSelection> {
  TextTheme? _textTheme;

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
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: ProBanner(),
        ),
        Expanded(child: ServerLocationListView(userPro: true,)),
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

class ServerLocationListView extends StatefulWidget {
  final bool userPro;

  const ServerLocationListView({
    super.key,
    required this.userPro,
  });

  @override
  State<ServerLocationListView> createState() => _ServerLocationListViewState();
}

class _ServerLocationListViewState extends State<ServerLocationListView> {
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
                style: _textTheme.labelLarge!.copyWith(
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
                    itemCount:5,
                    itemBuilder: (context, index) {
                      return _buildItem();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!widget.userPro)
          Container(
            color: AppColors.white.withValues(alpha: 0.5),
          )
      ],
    );
  }

  Widget _buildItem() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTile(
          label: 'Korea',
          icon: AppImagePaths.location,
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: AppColors.gray9,
            size: 20,
          ),
          onPressed: onItemTap,
        ),
        DividerSpace(),
      ],
    );
  }

  void onItemTap() {
    showAppBottomSheet(
      context: context,
      title: 'Korea',
      scrollControlDisabledMaxHeightRatio: .4,
      builder: (context, scrollController) {
        return ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            AppTile(
              label: 'USA - New Jersey',
              trailing: Radio<bool>(
                activeColor: AppColors.gray9,
                value: true,
                groupValue: true,
                onChanged: (value) {},
              ),
            )
          ],
        );
      },
    );
  }
}
