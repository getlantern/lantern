import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'data_cap_info_provider.g.dart';

@Riverpod(keepAlive: true)
class DataCapInfoNotifier extends _$DataCapInfoNotifier {
  @override
  Future<DataCapInfo> build() async {
    state = AsyncLoading();

    final lanternService = ref.watch(lanternServiceProvider);
    final result = await lanternService.getDataCapInfo();
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        throw Exception('Failed to fetch data cap info: $failure');
      },
      (dataCapInfo) {
        state = AsyncData(dataCapInfo);
        return dataCapInfo;
      },
    );
  }
}
