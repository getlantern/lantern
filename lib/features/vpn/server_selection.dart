import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

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
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('pro_locations'.i18n,
              style: _textTheme?.labelLarge!.copyWith(
                color: AppColors.gray8,
              )),
        ),

        Expanded(
          child: AppCard(
            padding: EdgeInsets.zero,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: 5,
              itemBuilder: (context, index) {
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
                    ),
                    DividerSpace(),
                  ],
                );
              },
            ),
          ),
        )
      ],
    );
  }
}
