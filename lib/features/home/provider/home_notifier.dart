import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_notifier.g.dart';

@Riverpod()
class HomeNotifier extends _$HomeNotifier {
  @override
  void build() {
    ref.read(lanternServiceProvider).setupRadiance();
  }
}
