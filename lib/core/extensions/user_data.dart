import 'package:lantern/lantern/protos/protos/auth.pb.dart';

extension UserDataProX on UserResponse_UserData {
  bool get isPro => userLevel == 'pro';
}
