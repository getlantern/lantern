import 'package:auto_route/annotations.dart';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';

@RoutePage(name: 'JoinPrivateServer')
class JoinPrivateServer extends StatefulHookConsumerWidget {
  const JoinPrivateServer({super.key});

  @override
  ConsumerState<JoinPrivateServer> createState() => _JoinPrivateServerState();
}

class _JoinPrivateServerState extends ConsumerState<JoinPrivateServer> {
  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'join_private_server'.i18n,
      body: Column(
        children: <Widget>[
          SizedBox(height: 16),



        ],
      ),
    );
  }
}
