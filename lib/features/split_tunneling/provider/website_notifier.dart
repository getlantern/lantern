import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/website.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/split_tunneling/provider/split_tunnel_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'website_notifier.g.dart';

@Riverpod(keepAlive: true)
class SplitTunnelingWebsites extends _$SplitTunnelingWebsites {
  @override
  FutureOr<Set<Website>> build() async {
    final snapshot = await ref.watch(splitTunnelProvider.future);
    return snapshot
        .selectors(SplitTunnelFilterType.domainSuffix)
        .map((domain) => Website(domain: domain))
        .toSet();
  }

  Future<Failure?> refreshFromCore() =>
      ref.read(splitTunnelProvider.notifier).refresh();

  Future<List<Failure>> addWebsites(List<Website> websites) async {
    final failures = <Failure>[];
    for (final website in websites.toSet()) {
      final failure = await ref
          .read(splitTunnelProvider.notifier)
          .setSelector(
            SplitTunnelFilterType.domainSuffix,
            website.domain,
            selected: true,
          );
      if (failure != null) failures.add(failure);
    }
    return failures;
  }

  Future<Failure?> removeWebsite(Website website) => ref
      .read(splitTunnelProvider.notifier)
      .setSelector(
        SplitTunnelFilterType.domainSuffix,
        website.domain,
        selected: false,
      );
}
