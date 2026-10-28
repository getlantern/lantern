import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/core/models/website.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/features/split_tunneling/provider/split_tunnel_notifier.dart';
import 'package:lantern/features/split_tunneling/provider/website_notifier.dart';
import 'package:lantern/features/split_tunneling/website_input.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class WebsiteDomainInput extends HookConsumerWidget {
  const WebsiteDomainInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final busy = useState(false);
    final snapshot = ref.watch(splitTunnelProvider).value;
    final websites =
        ref.watch(splitTunnelingWebsitesProvider).value ?? const <Website>{};

    Future<void> add() async {
      if (busy.value || snapshot == null) return;
      busy.value = true;
      try {
        final input = controller.text.trim();
        if (input.isEmpty) throw const FormatException('Empty website input');
        final added = <Website>{};
        for (final part in input.split(',')) {
          parseSplitTunnelWebsite(part);
          final result = await ref
              .read(lanternServiceProvider)
              .normalizeSplitTunnelWebsite(part);
          final canonical = result.fold(
            (failure) => throw failure,
            (value) => validateCanonicalSplitTunnelWebsite(value),
          );
          final website = Website(domain: canonical);
          if (websites.contains(website) || !added.add(website)) {
            throw Failure(
              error: 'Duplicate website',
              localizedErrorMessage: 'split_tunnel_website_duplicate'.i18n.fill(
                [website.displayDomain],
              ),
            );
          }
        }
        if (!context.mounted) return;
        if (snapshot.policy == SplitTunnelPolicy.bypass) {
          final storage = sl<LocalStorageService>();
          if (!storage.hasSeenBypassWebsiteDialog) {
            var confirmed = false;
            final navigator = Navigator.of(context, rootNavigator: true);
            await AppDialog.show(
              context: context,
              header: Center(
                child: AppImage(path: AppImagePaths.info, height: 40),
              ),
              centeredTitle: true,
              title: 'bypass_website_first_time_title'.i18n,
              body: 'bypass_website_first_time_body'.i18n.fill([
                added.map((website) => website.displayDomain).join(', '),
              ]),
              primaryLabel: 'add'.i18n,
              dismissOnPrimary: false,
              onPrimaryPressed: () {
                confirmed = true;
                navigator.pop();
              },
              secondaryLabel: 'cancel'.i18n,
            );
            if (!confirmed || !context.mounted) return;
            await storage.markBypassWebsiteDialogSeen();
          }
        }
        if (!context.mounted) return;
        final failures = await ref
            .read(splitTunnelingWebsitesProvider.notifier)
            .addWebsites(added.toList());
        if (!context.mounted) return;
        if (failures.isEmpty) {
          controller.clear();
        } else {
          context.showSnackBarError(
            failures.map((failure) => failure.localizedErrorMessage).join('\n'),
          );
        }
      } catch (error) {
        if (context.mounted) {
          context.showSnackBarError(
            error is Failure
                ? error.localizedErrorMessage
                : 'split_tunnel_invalid_website'.i18n,
          );
        }
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'split_tunnel_enter_website'.i18n,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                fieldKey: const Key('split_tunneling.website.input'),
                prefixIcon: AppImagePaths.web,
                controller: controller,
                hintText: '',
              ),
            ),
            AppTextButton(
              key: const Key('split_tunneling.website.add_button'),
              label: 'add'.i18n,
              textColor: context.textPrimary,
              onPressed: busy.value || snapshot == null ? null : add,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'split_tunnel_wildcard_hint'.i18n,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.textTertiary,
              height: 1.6,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
