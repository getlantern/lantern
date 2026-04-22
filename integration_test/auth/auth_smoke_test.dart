import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'auth_smoke_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Auth smoke: sign in success', runAuthSignInSuccessSmoke);
  testWidgets('Auth smoke: sign in failure', runAuthSignInFailureSmoke);
  testWidgets('Auth smoke: sign up success', runAuthSignUpSuccessSmoke);
  testWidgets(
    'Auth smoke: logout clears session',
    runAuthLogoutClearsSessionSmoke,
  );
  testWidgets(
    'Auth smoke: delete account clears session',
    runAuthDeleteAccountClearsSessionSmoke,
  );
}
