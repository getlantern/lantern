import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/split_tunneling/website.dart';
import 'package:lantern/core/split_tunneling/split_tunneling_notifier.dart';
import 'package:lantern/core/widgets/search_bar.dart';
import 'package:lantern/features/split_tunneling/section_label.dart';

// Mock data representing websites
final List<Website> _mockDomains = [
  Website(domain: "google.com", isEnabled: false),
  Website(domain: "linkedin.com", isEnabled: true),
  Website(domain: "weather.com", isEnabled: true),
  Website(domain: "nytimes.com", isEnabled: false),
];

@RoutePage(name: 'WebsiteSplitTunneling')
class WebsiteSplitTunneling extends HookConsumerWidget {
  const WebsiteSplitTunneling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchEnabled = useState(false);
    final searchQuery = ref.watch(searchQueryProvider);

    final enabledWebsites = ref.watch(splitTunnelingWebsitesProvider);
    return BaseScreen(
      title: 'website_split_tunneling'.i18n,
      appBar: CustomAppBar(
        title: searchEnabled.value
            ? AppSearchBar(
                hintText: 'search_websites'.i18n,
              )
            : 'website_split_tunneling'.i18n,
        actionsPadding: EdgeInsets.only(right: 24.0),
        actions: [
          AppIconButton(
            onPressed: () => searchEnabled.value = !searchEnabled.value,
            path: AppImagePaths.search,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(height: defaultSize),
          SearchSection(),
          SizedBox(height: defaultSize),
          AppTile(
            icon: AppImagePaths.bypassList,
            label: 'default_bypass'.i18n,
            trailing: AppImage(path: AppImagePaths.arrowForward),
          ),
          SizedBox(height: defaultSize),
          // Websites bypassing the VPN
          if (enabledWebsites.isNotEmpty) ...[
            SectionLabel(
              'websites_bypassing_vpn'.i18n.fill([enabledWebsites.length]),
            ),
            ...enabledWebsites.map((website) => _WebsiteRow(
                  website: website,
                  onToggle: () => ref
                      .read(splitTunnelingWebsitesProvider.notifier)
                      .toggleWebsite(website),
                )),
          ],
          SizedBox(height: defaultSize),
        ],
      ),
    );
  }
}

class _WebsiteRow extends StatelessWidget {
  final Website website;
  final VoidCallback onToggle;

  const _WebsiteRow({
    required this.website,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppTile(
      label: website.domain,
      trailing: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: IconButton(
          icon: AppImage(
            path: website.isEnabled ? AppImagePaths.minus : AppImagePaths.plus,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

class SearchSection extends HookConsumerWidget {
  const SearchSection({super.key});

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'enter_url_or_ip'.i18n,
            style: TextStyle(
              color: Color(0xFF3D454D),
              fontSize: 14,
              fontFamily: 'Urbanist',
              fontWeight: FontWeight.w500,
              height: 1.43,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Color(0xFFDEDFDF), width: 1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              SizedBox(width: 8),
              Icon(Icons.link, color: Color(0xFFBFBFBF), size: 24),
              SizedBox(width: 8),
              Flexible(
                child: TextField(
                  controller: textController,
                  decoration: InputDecoration(
                    hintText: 'enter_url'.i18n,
                    hintStyle: TextStyle(
                      color: Color(0xFFBFBFBF),
                      fontSize: 14,
                      fontFamily: 'Urbanist',
                      fontWeight: FontWeight.w400,
                      height: 1.64,
                    ),
                    border: InputBorder.none, // Removes default border
                  ),
                  style: TextStyle(color: Colors.black),
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextButton(
                  onPressed: validateAndExtractDomain,
                  child: Text(
                    'add'.i18n,
                    style: AppTestStyles.labelLarge.copyWith(
                      color: Color(0xFF1A1B1C),
                      fontSize: 16,
                      fontFamily: 'Urbanist',
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'use_commas'.i18n,
            style: AppTestStyles.labelSmall,
          ),
        ),
        SizedBox(width: 10),
      ],
    );
  }
}
