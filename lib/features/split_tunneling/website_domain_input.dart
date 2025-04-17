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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
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

    void validateAndExtractDomain() {
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

      ref.read(splitTunnelingWebsitesProvider.notifier).addWebsites(added);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'enter_url_or_ip'.i18n,
              style: AppTestStyles.bodySmall.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFDEDFDF)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.link, color: Color(0xFFBFBFBF), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: textController,
                    style: AppTestStyles.bodyMedium,
                    onSubmitted: (_) => validateAndExtractDomain(),
                    decoration: InputDecoration(
                      hintText: 'enter_url'.i18n,
                      hintStyle: AppTestStyles.bodySmall.copyWith(
                        color: const Color(0xFFBFBFBF),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: validateAndExtractDomain,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.black,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: Size.zero,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: Text(
                    'add'.i18n,
                    style: AppTestStyles.titleSmall.copyWith(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'use_commas'.i18n,
              style: AppTestStyles.bodyMedium.copyWith(
                color: AppColors.gray7,
                height: 1.6,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
