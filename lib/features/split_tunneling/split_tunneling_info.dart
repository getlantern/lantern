import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/split_tunneling/split_tunneling_mode.dart';
import 'package:lantern/core/widgets/divider_space.dart';

@RoutePage(name: 'SplitTunnelingInfo')
class SplitTunnelingInfo extends HookConsumerWidget {
  const SplitTunnelingInfo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('automatic'.i18n, style: TextStyle(color: Colors.black)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Card(
        borderOnForeground: false,
        color: Colors.white,
        child: Container(
          width: MediaQuery.of(context).size.width,
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
                SectionTitle(text: "🌍 Region-Specific Rules"),
                InfoText(
                  text:
                      "Lantern uses different routing rules depending on your location:",
                ),
                DividerSpace(),

                // Censored Regions
                SubsectionTitle(text: "🔒 In censored regions:"),
                InfoText(
                  text:
                      "Blocked websites and apps (news, messaging, restricted services) are proxied.",
                ),
                InfoText(
                  text:
                      "Most unblocked websites bypass the VPN for faster browsing.",
                ),
                DividerSpace(),

                // Uncensored Regions
                SubsectionTitle(text: "✅ In uncensored regions:"),
                InfoText(
                  text:
                      "Only trusted websites and services bypass the VPN by default.",
                ),
                InfoText(
                  text:
                      "These include HTTPS-encrypted sites with public or non-sensitive content like shopping, weather, and software updates.",
                ),
                SizedBox(height: 16),
                // Routing Rules
                InfoText(
                  text:
                      "These rules vary by country and are updated regularly. View the full list of routing rules.",
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class SubsectionTitle extends StatelessWidget {
  final String text;
  const SubsectionTitle({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class InfoText extends StatelessWidget {
  final String text;
  const InfoText({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
}
