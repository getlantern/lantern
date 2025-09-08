import 'package:lantern/core/utils/failure.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

part 'data_cap_info_provider.g.dart';

@riverpod
Future<Either<Failure, DataCapInfo>> dataCapInfo(Ref ref) async {
  final service = ref.watch(lanternServiceProvider);
  return service.getDataCapInfo();
}
