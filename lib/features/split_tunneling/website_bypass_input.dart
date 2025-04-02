import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/split_tunneling/website.dart';
import 'package:lantern/core/split_tunneling/website_notifier.dart';

class WebsiteBypassInput extends HookConsumerWidget {
  const WebsiteBypassInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textController = useTextEditingController();

    final enabledWebsites = ref.watch(splitTunnelingWebsitesProvider);

    void showSnackbar(BuildContext context, String message) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }

    bool isValidDomain(String input) {
      final domainPattern =
          r'^(?!-)[A-Za-z0-9-]{1,63}(?<!-)\.[A-Za-z]{2,6}$'; // Matches google.com
      final regExp = RegExp(domainPattern);
      return regExp.hasMatch(input);
    }

    bool isValidIPv4(String input) {
      final ipv4Pattern = r'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$';
      final regExp = RegExp(ipv4Pattern);
      return regExp.hasMatch(input) &&
          input.split('.').every((segment) => int.parse(segment) <= 255);
    }

    bool isValidDomainOrIP(String input) {
      return isValidIPv4(input) || isValidDomain(input);
    }

    String extractDomain(Uri uri) {
      final hostParts = uri.host.split('.');
      if (hostParts.length > 2) {
        return "${hostParts[hostParts.length - 2]}.${hostParts.last}";
      }
      return uri.host;
    }

    // validate URL and extract the domain before adding it to the
    // split tunneling list
    void validateAndExtractDomain() {
      String inputText = textController.text.trim();

      if (inputText.isEmpty) {
        showSnackbar(context, "Please enter a URL or domain.");
        return;
      }

      try {
        if (!inputText.startsWith("http://") &&
            !inputText.startsWith("https://")) {
          // Assume HTTPS if scheme is missing
          inputText = "https://$inputText";
        }

        final uri = Uri.parse(inputText);

        // Check if it's a valid URL
        if (uri.host.isEmpty) {
          throw FormatException("Invalid URL format");
        }

        final domain = extractDomain(uri);

        if (!isValidDomainOrIP(domain)) {
          throw FormatException("Invalid domain");
        }

        final website = Website(domain: domain, isEnabled: true);
        print("Extracted domain: $domain");

        if (enabledWebsites.contains(website)) {
          showSnackbar(context, "Domain already added");
          return;
        }

        ref
            .read(splitTunnelingWebsitesProvider.notifier)
            .toggleWebsite(website);
      } catch (e) {
        showSnackbar(
            context, "Invalid URL: Please enter a valid domain or URL.");
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'enter_url_or_ip'.i18n,
            style: AppTestStyles.bodySmall,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFDEDFDF)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                const Icon(Icons.link, color: Color(0xFFBFBFBF), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      hintText: 'enter_url'.i18n,
                      hintStyle: AppTestStyles.bodySmall.copyWith(
                        color: const Color(0xFFBFBFBF),
                      ),
                      border: InputBorder.none,
                    ),
                    style: AppTestStyles.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: validateAndExtractDomain,
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
          Text(
            'use_commas'.i18n,
            style: AppTestStyles.labelSmall,
          ),
        ],
      ),
    );
  }
}
