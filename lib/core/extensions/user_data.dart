import 'package:lantern/core/models/user.dart';

extension UserDataProX on UserDataModel {
  bool get isPro => userLevel == 'pro';
}
