import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/info_row.dart';

@RoutePage(name: 'SmartRouting')
class SmartRouting extends StatelessWidget {
  const SmartRouting({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BaseScreen(
      title: 'routing_mode'.i18n,
      body: Column(
        children: <Widget>[
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppTile(
                  icon: AppRadioButton(value: false),
                  label: 'smart_routing'.i18n,
                  subtitle: Text(
                    'region_optimized_routing'.i18n,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium!.copyWith(
                      color: AppColors.gray7,
                      letterSpacing: 0.0,
                    ),
                  ),
                ),
                DividerSpace(),
                AppTile(
                  icon: AppRadioButton(value: false),
                  label: 'full_tunnel'.i18n,
                  subtitle: Text(
                    'all_traffic_through_vpn'.i18n,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium!.copyWith(
                      color: AppColors.gray7,
                      letterSpacing: 0.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: size24),
          InfoRow(text: 'smart_routing_description'.i18n)
        ],
      ),
    );
  }
}
