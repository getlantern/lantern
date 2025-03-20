import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/widgets/custom_app_bar.dart';
import 'package:lantern/core/widgets/divider_space.dart';

@RoutePage(name: 'SplitTunnelingInfo')
class SplitTunnelingInfo extends StatelessWidget {
  const SplitTunnelingInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, // Match the card background
        elevation: 0, // Remove shadow
        title: Text("Automatic Mode", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Card(
        borderOnForeground: false,
        color: Colors.white, // Semi-transparent background
        child: Container(
          width:
              MediaQuery.of(context).size.width * 0.96, // 90% of screen width
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(0),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    "Lantern intelligently routes internet traffic based on your location, ensuring secure access while keeping your connection fast by only using a VPN when necessary.",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                  ),
                ),
                DividerSpace(),

                // Region-Specific Rules Section
                _sectionTitle("🌍 Region-Specific Rules"),
                Text(
                  "Lantern uses different routing rules depending on your location:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                ),
                DividerSpace(),

                // Censored Regions
                _subsectionTitle("🔒 In censored regions:"),
                _infoText(
                    "Blocked websites and apps (news, messaging, restricted services) are proxied."),
                _infoText(
                    "Most unblocked websites bypass the VPN for faster browsing."),
                DividerSpace(),

                // Uncensored Regions
                _subsectionTitle("✅ In uncensored regions:"),
                _infoText(
                    "Only trusted websites and services bypass the VPN by default."),
                _infoText(
                    "These include HTTPS-encrypted sites with public or non-sensitive content like shopping, weather, and software updates."),
                SizedBox(height: 16),

                // Routing Rules
                _infoText(
                    "These rules vary by country and are updated regularly. View the full list of routing rules."),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Section Title
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
    );
  }

  // Subsection Title
  Widget _subsectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  // Regular Info Text
  Widget _infoText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• ",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  // Settings Item
  Widget _settingsItem(IconData icon, String text,
      {String? trailingText, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: isBold ? FontWeight.w600 : FontWeight.w400),
            ),
          ),
          if (trailingText != null)
            Text(
              trailingText,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}
