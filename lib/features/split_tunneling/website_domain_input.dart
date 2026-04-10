import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/website.dart';
import 'package:lantern/features/split_tunneling/provider/website_notifier.dart';

class WebsiteDomainInput extends HookConsumerWidget {
  const WebsiteDomainInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textController = useTextEditingController();
    final enabledWebsites = ref.watch(splitTunnelingWebsitesProvider);

    void showSnackbar(String message) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    // validate URL and extract the domain before adding it to the
    // split tunneling list
    Website? validateDomain(String input, void Function(String) onError) {
      final domain = UrlUtils.extractDomain(input);

      if (!UrlUtils.isValidDomainOrIP(domain)) {
        onError("Invalid domain");
        return null;
      }

      final website = Website(domain: domain);
      if (enabledWebsites.contains(website)) {
        onError("$domain already added");
        return null;
      }

      return website;
    }

    Future<void> validateAndExtractDomain() async {
      final inputText = textController.text.trim();

      if (inputText.isEmpty) {
        showSnackbar("Please enter a URL or domain.");
        return;
      }

      final parts = inputText
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();

      final errors = <String>[];
      final added = <Website>[];

      for (final part in parts) {
        final website = validateDomain(part, (msg) => errors.add(msg));
        if (website != null) {
          added.add(website);
        }
      }

      if (added.isNotEmpty) {
        textController.clear();
      }

      if (errors.isNotEmpty) {
        showSnackbar(errors.join('\n'));
        return;
      }

      final failures = await ref
          .read(splitTunnelingWebsitesProvider.notifier)
          .addWebsites(added);

      if (!context.mounted || failures.isEmpty) {
        return;
      }

      showSnackbar(
        failures.map((failure) => failure.localizedErrorMessage).join('\n'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'enter_url_or_ip'.i18n,
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
                controller: textController,
                hintText: '',
              ),
            ),
            AppTextButton(
              key: const Key('split_tunneling.website.add_button'),
              label: 'add'.i18n,
              textColor: context.textPrimary,
              onPressed: validateAndExtractDomain,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'use_commas'.i18n,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.textTertiary,
              height: 1.6,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
