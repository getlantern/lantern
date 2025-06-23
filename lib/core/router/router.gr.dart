// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i35;
import 'package:collection/collection.dart' as _i38;
import 'package:flutter/material.dart' as _i36;
import 'package:lantern/core/common/common.dart' as _i37;
import 'package:lantern/core/widgets/app_webview.dart' as _i4;
import 'package:lantern/features/account/account.dart' as _i1;
import 'package:lantern/features/account/delete_account.dart' as _i9;
import 'package:lantern/features/auth/activation_code.dart' as _i2;
import 'package:lantern/features/auth/add_email.dart' as _i3;
import 'package:lantern/features/auth/choose_payment_method.dart' as _i6;
import 'package:lantern/features/auth/confirm_email.dart' as _i7;
import 'package:lantern/features/auth/create_password.dart' as _i8;
import 'package:lantern/features/auth/reset_password.dart' as _i24;
import 'package:lantern/features/auth/reset_password_email.dart' as _i25;
import 'package:lantern/features/auth/sign_in_email.dart' as _i28;
import 'package:lantern/features/auth/sign_in_password.dart' as _i29;
import 'package:lantern/features/home/home.dart' as _i12;
import 'package:lantern/features/language/language.dart' as _i14;
import 'package:lantern/features/logs/logs.dart' as _i15;
import 'package:lantern/features/plans/plans.dart' as _i17;
import 'package:lantern/features/private_server/menually_server_setup.dart'
    as _i16;
import 'package:lantern/features/private_server/private_server_deploy.dart'
    as _i18;
import 'package:lantern/features/private_server/private_server_locations.dart'
    as _i19;
import 'package:lantern/features/private_server/private_server_setup.dart'
    as _i20;
import 'package:lantern/features/private_server/private_sever_details.dart'
    as _i21;
import 'package:lantern/features/qr_scanner/qr_code_scanner.dart' as _i22;
import 'package:lantern/features/report_Issue/report_issue.dart' as _i23;
import 'package:lantern/features/setting/download_links.dart' as _i10;
import 'package:lantern/features/setting/follow_us.dart' as _i11;
import 'package:lantern/features/setting/invite_friends.dart' as _i13;
import 'package:lantern/features/setting/setting.dart' as _i27;
import 'package:lantern/features/setting/vpn_setting.dart' as _i33;
import 'package:lantern/features/split_tunneling/apps_split_tunneling.dart'
    as _i5;
import 'package:lantern/features/split_tunneling/split_tunneling.dart' as _i30;
import 'package:lantern/features/split_tunneling/split_tunneling_info.dart'
    as _i31;
import 'package:lantern/features/split_tunneling/website_split_tunneling.dart'
    as _i34;
import 'package:lantern/features/support/support.dart' as _i32;
import 'package:lantern/features/vpn/server_selection.dart' as _i26;

/// generated route for
/// [_i1.Account]
class Account extends _i35.PageRouteInfo<void> {
  const Account({List<_i35.PageRouteInfo>? children})
      : super(Account.name, initialChildren: children);

  static const String name = 'Account';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i1.Account();
    },
  );
}

/// generated route for
/// [_i2.ActivationCode]
class ActivationCode extends _i35.PageRouteInfo<ActivationCodeArgs> {
  ActivationCode({
    _i36.Key? key,
    required String email,
    required String code,
    List<_i35.PageRouteInfo>? children,
  }) : super(
          ActivationCode.name,
          args: ActivationCodeArgs(key: key, email: email, code: code),
          initialChildren: children,
        );

  static const String name = 'ActivationCode';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ActivationCodeArgs>();
      return _i2.ActivationCode(
        key: args.key,
        email: args.email,
        code: args.code,
      );
    },
  );
}

class ActivationCodeArgs {
  const ActivationCodeArgs({this.key, required this.email, required this.code});

  final _i36.Key? key;

  final String email;

  final String code;

  @override
  String toString() {
    return 'ActivationCodeArgs{key: $key, email: $email, code: $code}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ActivationCodeArgs) return false;
    return key == other.key && email == other.email && code == other.code;
  }

  @override
  int get hashCode => key.hashCode ^ email.hashCode ^ code.hashCode;
}

/// generated route for
/// [_i3.AddEmail]
class AddEmail extends _i35.PageRouteInfo<AddEmailArgs> {
  AddEmail({
    _i36.Key? key,
    _i37.AuthFlow authFlow = _i37.AuthFlow.signUp,
    List<_i35.PageRouteInfo>? children,
  }) : super(
          AddEmail.name,
          args: AddEmailArgs(key: key, authFlow: authFlow),
          initialChildren: children,
        );

  static const String name = 'AddEmail';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AddEmailArgs>(
        orElse: () => const AddEmailArgs(),
      );
      return _i3.AddEmail(key: args.key, authFlow: args.authFlow);
    },
  );
}

class AddEmailArgs {
  const AddEmailArgs({this.key, this.authFlow = _i37.AuthFlow.signUp});

  final _i36.Key? key;

  final _i37.AuthFlow authFlow;

  @override
  String toString() {
    return 'AddEmailArgs{key: $key, authFlow: $authFlow}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AddEmailArgs) return false;
    return key == other.key && authFlow == other.authFlow;
  }

  @override
  int get hashCode => key.hashCode ^ authFlow.hashCode;
}

/// generated route for
/// [_i4.AppWebView]
class AppWebview extends _i35.PageRouteInfo<AppWebviewArgs> {
  AppWebview({
    _i36.Key? key,
    required String title,
    required String url,
    List<_i35.PageRouteInfo>? children,
  }) : super(
          AppWebview.name,
          args: AppWebviewArgs(key: key, title: title, url: url),
          initialChildren: children,
        );

  static const String name = 'AppWebview';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AppWebviewArgs>();
      return _i4.AppWebView(key: args.key, title: args.title, url: args.url);
    },
  );
}

class AppWebviewArgs {
  const AppWebviewArgs({this.key, required this.title, required this.url});

  final _i36.Key? key;

  final String title;

  final String url;

  @override
  String toString() {
    return 'AppWebviewArgs{key: $key, title: $title, url: $url}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AppWebviewArgs) return false;
    return key == other.key && title == other.title && url == other.url;
  }

  @override
  int get hashCode => key.hashCode ^ title.hashCode ^ url.hashCode;
}

/// generated route for
/// [_i5.AppsSplitTunneling]
class AppsSplitTunneling extends _i35.PageRouteInfo<void> {
  const AppsSplitTunneling({List<_i35.PageRouteInfo>? children})
      : super(AppsSplitTunneling.name, initialChildren: children);

  static const String name = 'AppsSplitTunneling';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i5.AppsSplitTunneling();
    },
  );
}

/// generated route for
/// [_i6.ChoosePaymentMethod]
class ChoosePaymentMethod extends _i35.PageRouteInfo<ChoosePaymentMethodArgs> {
  ChoosePaymentMethod({
    _i36.Key? key,
    required String email,
    String? code,
    required _i37.AuthFlow authFlow,
    List<_i35.PageRouteInfo>? children,
  }) : super(
          ChoosePaymentMethod.name,
          args: ChoosePaymentMethodArgs(
            key: key,
            email: email,
            code: code,
            authFlow: authFlow,
          ),
          initialChildren: children,
        );

  static const String name = 'ChoosePaymentMethod';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ChoosePaymentMethodArgs>();
      return _i6.ChoosePaymentMethod(
        key: args.key,
        email: args.email,
        code: args.code,
        authFlow: args.authFlow,
      );
    },
  );
}

class ChoosePaymentMethodArgs {
  const ChoosePaymentMethodArgs({
    this.key,
    required this.email,
    this.code,
    required this.authFlow,
  });

  final _i36.Key? key;

  final String email;

  final String? code;

  final _i37.AuthFlow authFlow;

  @override
  String toString() {
    return 'ChoosePaymentMethodArgs{key: $key, email: $email, code: $code, authFlow: $authFlow}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChoosePaymentMethodArgs) return false;
    return key == other.key &&
        email == other.email &&
        code == other.code &&
        authFlow == other.authFlow;
  }

  @override
  int get hashCode =>
      key.hashCode ^ email.hashCode ^ code.hashCode ^ authFlow.hashCode;
}

/// generated route for
/// [_i7.ConfirmEmail]
class ConfirmEmail extends _i35.PageRouteInfo<ConfirmEmailArgs> {
  ConfirmEmail({
    _i36.Key? key,
    required String email,
    _i37.AuthFlow authFlow = _i37.AuthFlow.signUp,
    List<_i35.PageRouteInfo>? children,
  }) : super(
          ConfirmEmail.name,
          args: ConfirmEmailArgs(key: key, email: email, authFlow: authFlow),
          initialChildren: children,
        );

  static const String name = 'ConfirmEmail';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ConfirmEmailArgs>();
      return _i7.ConfirmEmail(
        key: args.key,
        email: args.email,
        authFlow: args.authFlow,
      );
    },
  );
}

class ConfirmEmailArgs {
  const ConfirmEmailArgs({
    this.key,
    required this.email,
    this.authFlow = _i37.AuthFlow.signUp,
  });

  final _i36.Key? key;

  final String email;

  final _i37.AuthFlow authFlow;

  @override
  String toString() {
    return 'ConfirmEmailArgs{key: $key, email: $email, authFlow: $authFlow}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ConfirmEmailArgs) return false;
    return key == other.key &&
        email == other.email &&
        authFlow == other.authFlow;
  }

  @override
  int get hashCode => key.hashCode ^ email.hashCode ^ authFlow.hashCode;
}

/// generated route for
/// [_i8.CreatePassword]
class CreatePassword extends _i35.PageRouteInfo<CreatePasswordArgs> {
  CreatePassword({
    _i36.Key? key,
    required String email,
    required _i37.AuthFlow authFlow,
    required String code,
    List<_i35.PageRouteInfo>? children,
  }) : super(
          CreatePassword.name,
          args: CreatePasswordArgs(
            key: key,
            email: email,
            authFlow: authFlow,
            code: code,
          ),
          initialChildren: children,
        );

  static const String name = 'CreatePassword';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CreatePasswordArgs>();
      return _i8.CreatePassword(
        key: args.key,
        email: args.email,
        authFlow: args.authFlow,
        code: args.code,
      );
    },
  );
}

class CreatePasswordArgs {
  const CreatePasswordArgs({
    this.key,
    required this.email,
    required this.authFlow,
    required this.code,
  });

  final _i36.Key? key;

  final String email;

  final _i37.AuthFlow authFlow;

  final String code;

  @override
  String toString() {
    return 'CreatePasswordArgs{key: $key, email: $email, authFlow: $authFlow, code: $code}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CreatePasswordArgs) return false;
    return key == other.key &&
        email == other.email &&
        authFlow == other.authFlow &&
        code == other.code;
  }

  @override
  int get hashCode =>
      key.hashCode ^ email.hashCode ^ authFlow.hashCode ^ code.hashCode;
}

/// generated route for
/// [_i9.DeleteAccount]
class DeleteAccount extends _i35.PageRouteInfo<void> {
  const DeleteAccount({List<_i35.PageRouteInfo>? children})
      : super(DeleteAccount.name, initialChildren: children);

  static const String name = 'DeleteAccount';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i9.DeleteAccount();
    },
  );
}

/// generated route for
/// [_i10.DownloadLinks]
class DownloadLinks extends _i35.PageRouteInfo<void> {
  const DownloadLinks({List<_i35.PageRouteInfo>? children})
      : super(DownloadLinks.name, initialChildren: children);

  static const String name = 'DownloadLinks';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i10.DownloadLinks();
    },
  );
}

/// generated route for
/// [_i11.FollowUs]
class FollowUs extends _i35.PageRouteInfo<FollowUsArgs> {
  FollowUs({_i36.Key? key, List<_i35.PageRouteInfo>? children})
      : super(
          FollowUs.name,
          args: FollowUsArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'FollowUs';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<FollowUsArgs>(
        orElse: () => const FollowUsArgs(),
      );
      return _i11.FollowUs(key: args.key);
    },
  );
}

class FollowUsArgs {
  const FollowUsArgs({this.key});

  final _i36.Key? key;

  @override
  String toString() {
    return 'FollowUsArgs{key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FollowUsArgs) return false;
    return key == other.key;
  }

  @override
  int get hashCode => key.hashCode;
}

/// generated route for
/// [_i12.Home]
class Home extends _i35.PageRouteInfo<HomeArgs> {
  Home({_i36.Key? key, List<_i35.PageRouteInfo>? children})
      : super(
          Home.name,
          args: HomeArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'Home';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HomeArgs>(orElse: () => const HomeArgs());
      return _i12.Home(key: args.key);
    },
  );
}

class HomeArgs {
  const HomeArgs({this.key});

  final _i36.Key? key;

  @override
  String toString() {
    return 'HomeArgs{key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HomeArgs) return false;
    return key == other.key;
  }

  @override
  int get hashCode => key.hashCode;
}

/// generated route for
/// [_i13.InviteFriends]
class InviteFriends extends _i35.PageRouteInfo<void> {
  const InviteFriends({List<_i35.PageRouteInfo>? children})
      : super(InviteFriends.name, initialChildren: children);

  static const String name = 'InviteFriends';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i13.InviteFriends();
    },
  );
}

/// generated route for
/// [_i14.Language]
class Language extends _i35.PageRouteInfo<void> {
  const Language({List<_i35.PageRouteInfo>? children})
      : super(Language.name, initialChildren: children);

  static const String name = 'Language';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i14.Language();
    },
  );
}

/// generated route for
/// [_i15.Logs]
class Logs extends _i35.PageRouteInfo<void> {
  const Logs({List<_i35.PageRouteInfo>? children})
      : super(Logs.name, initialChildren: children);

  static const String name = 'Logs';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i15.Logs();
    },
  );
}

/// generated route for
/// [_i16.ManuallyServerSetup]
class ManuallyServerSetup extends _i35.PageRouteInfo<void> {
  const ManuallyServerSetup({List<_i35.PageRouteInfo>? children})
      : super(ManuallyServerSetup.name, initialChildren: children);

  static const String name = 'ManuallyServerSetup';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i16.ManuallyServerSetup();
    },
  );
}

/// generated route for
/// [_i17.Plans]
class Plans extends _i35.PageRouteInfo<void> {
  const Plans({List<_i35.PageRouteInfo>? children})
      : super(Plans.name, initialChildren: children);

  static const String name = 'Plans';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i17.Plans();
    },
  );
}

/// generated route for
/// [_i18.PrivateServerDeploy]
class PrivateServerDeploy extends _i35.PageRouteInfo<PrivateServerDeployArgs> {
  PrivateServerDeploy({
    _i36.Key? key,
    required String serverName,
    List<_i35.PageRouteInfo>? children,
  }) : super(
          PrivateServerDeploy.name,
          args: PrivateServerDeployArgs(key: key, serverName: serverName),
          initialChildren: children,
        );

  static const String name = 'PrivateServerDeploy';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PrivateServerDeployArgs>();
      return _i18.PrivateServerDeploy(
        key: args.key,
        serverName: args.serverName,
      );
    },
  );
}

class PrivateServerDeployArgs {
  const PrivateServerDeployArgs({this.key, required this.serverName});

  final _i36.Key? key;

  final String serverName;

  @override
  String toString() {
    return 'PrivateServerDeployArgs{key: $key, serverName: $serverName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PrivateServerDeployArgs) return false;
    return key == other.key && serverName == other.serverName;
  }

  @override
  int get hashCode => key.hashCode ^ serverName.hashCode;
}

/// generated route for
/// [_i19.PrivateServerLocation]
class PrivateServerLocation
    extends _i35.PageRouteInfo<PrivateServerLocationArgs> {
  PrivateServerLocation({
    _i36.Key? key,
    required List<String> location,
    required String? selectedLocation,
    required dynamic Function(String) onLocationSelected,
    List<_i35.PageRouteInfo>? children,
  }) : super(
          PrivateServerLocation.name,
          args: PrivateServerLocationArgs(
            key: key,
            location: location,
            selectedLocation: selectedLocation,
            onLocationSelected: onLocationSelected,
          ),
          initialChildren: children,
        );

  static const String name = 'PrivateServerLocation';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PrivateServerLocationArgs>();
      return _i19.PrivateServerLocation(
        key: args.key,
        location: args.location,
        selectedLocation: args.selectedLocation,
        onLocationSelected: args.onLocationSelected,
      );
    },
  );
}

class PrivateServerLocationArgs {
  const PrivateServerLocationArgs({
    this.key,
    required this.location,
    required this.selectedLocation,
    required this.onLocationSelected,
  });

  final _i36.Key? key;

  final List<String> location;

  final String? selectedLocation;

  final dynamic Function(String) onLocationSelected;

  @override
  String toString() {
    return 'PrivateServerLocationArgs{key: $key, location: $location, selectedLocation: $selectedLocation, onLocationSelected: $onLocationSelected}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PrivateServerLocationArgs) return false;
    return key == other.key &&
        const _i38.ListEquality().equals(location, other.location) &&
        selectedLocation == other.selectedLocation;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      const _i38.ListEquality().hash(location) ^
      selectedLocation.hashCode;
}

/// generated route for
/// [_i20.PrivateServerSetup]
class PrivateServerSetup extends _i35.PageRouteInfo<void> {
  const PrivateServerSetup({List<_i35.PageRouteInfo>? children})
      : super(PrivateServerSetup.name, initialChildren: children);

  static const String name = 'PrivateServerSetup';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i20.PrivateServerSetup();
    },
  );
}

/// generated route for
/// [_i21.PrivateSeverDetails]
class PrivateServerDetails
    extends _i35.PageRouteInfo<PrivateServerDetailsArgs> {
  PrivateServerDetails({
    _i36.Key? key,
    required List<String> accounts,
    List<_i35.PageRouteInfo>? children,
  }) : super(
          PrivateServerDetails.name,
          args: PrivateServerDetailsArgs(key: key, accounts: accounts),
          initialChildren: children,
        );

  static const String name = 'PrivateServerDetails';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PrivateServerDetailsArgs>();
      return _i21.PrivateSeverDetails(key: args.key, accounts: args.accounts);
    },
  );
}

class PrivateServerDetailsArgs {
  const PrivateServerDetailsArgs({this.key, required this.accounts});

  final _i36.Key? key;

  final List<String> accounts;

  @override
  String toString() {
    return 'PrivateServerDetailsArgs{key: $key, accounts: $accounts}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PrivateServerDetailsArgs) return false;
    return key == other.key &&
        const _i38.ListEquality().equals(accounts, other.accounts);
  }

  @override
  int get hashCode => key.hashCode ^ const _i38.ListEquality().hash(accounts);
}

/// generated route for
/// [_i22.QrCodeScanner]
class QrCodeScanner extends _i35.PageRouteInfo<QrCodeScannerArgs> {
  QrCodeScanner({_i36.Key? key, List<_i35.PageRouteInfo>? children})
      : super(
          QrCodeScanner.name,
          args: QrCodeScannerArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'QrCodeScanner';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<QrCodeScannerArgs>(
        orElse: () => const QrCodeScannerArgs(),
      );
      return _i22.QrCodeScanner(key: args.key);
    },
  );
}

class QrCodeScannerArgs {
  const QrCodeScannerArgs({this.key});

  final _i36.Key? key;

  @override
  String toString() {
    return 'QrCodeScannerArgs{key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QrCodeScannerArgs) return false;
    return key == other.key;
  }

  @override
  int get hashCode => key.hashCode;
}

/// generated route for
/// [_i23.ReportIssue]
class ReportIssue extends _i35.PageRouteInfo<ReportIssueArgs> {
  ReportIssue({
    _i36.Key? key,
    String? description,
    List<_i35.PageRouteInfo>? children,
  }) : super(
          ReportIssue.name,
          args: ReportIssueArgs(key: key, description: description),
          initialChildren: children,
        );

  static const String name = 'ReportIssue';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ReportIssueArgs>(
        orElse: () => const ReportIssueArgs(),
      );
      return _i23.ReportIssue(key: args.key, description: args.description);
    },
  );
}

class ReportIssueArgs {
  const ReportIssueArgs({this.key, this.description});

  final _i36.Key? key;

  final String? description;

  @override
  String toString() {
    return 'ReportIssueArgs{key: $key, description: $description}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ReportIssueArgs) return false;
    return key == other.key && description == other.description;
  }

  @override
  int get hashCode => key.hashCode ^ description.hashCode;
}

/// generated route for
/// [_i24.ResetPassword]
class ResetPassword extends _i35.PageRouteInfo<ResetPasswordArgs> {
  ResetPassword({
    _i36.Key? key,
    required String email,
    required String code,
    List<_i35.PageRouteInfo>? children,
  }) : super(
          ResetPassword.name,
          args: ResetPasswordArgs(key: key, email: email, code: code),
          initialChildren: children,
        );

  static const String name = 'ResetPassword';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ResetPasswordArgs>();
      return _i24.ResetPassword(
        key: args.key,
        email: args.email,
        code: args.code,
      );
    },
  );
}

class ResetPasswordArgs {
  const ResetPasswordArgs({this.key, required this.email, required this.code});

  final _i36.Key? key;

  final String email;

  final String code;

  @override
  String toString() {
    return 'ResetPasswordArgs{key: $key, email: $email, code: $code}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ResetPasswordArgs) return false;
    return key == other.key && email == other.email && code == other.code;
  }

  @override
  int get hashCode => key.hashCode ^ email.hashCode ^ code.hashCode;
}

/// generated route for
/// [_i25.ResetPasswordEmail]
class ResetPasswordEmail extends _i35.PageRouteInfo<ResetPasswordEmailArgs> {
  ResetPasswordEmail({
    _i36.Key? key,
    String? email,
    List<_i35.PageRouteInfo>? children,
  }) : super(
          ResetPasswordEmail.name,
          args: ResetPasswordEmailArgs(key: key, email: email),
          initialChildren: children,
        );

  static const String name = 'ResetPasswordEmail';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ResetPasswordEmailArgs>(
        orElse: () => const ResetPasswordEmailArgs(),
      );
      return _i25.ResetPasswordEmail(key: args.key, email: args.email);
    },
  );
}

class ResetPasswordEmailArgs {
  const ResetPasswordEmailArgs({this.key, this.email});

  final _i36.Key? key;

  final String? email;

  @override
  String toString() {
    return 'ResetPasswordEmailArgs{key: $key, email: $email}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ResetPasswordEmailArgs) return false;
    return key == other.key && email == other.email;
  }

  @override
  int get hashCode => key.hashCode ^ email.hashCode;
}

/// generated route for
/// [_i26.ServerSelection]
class ServerSelection extends _i35.PageRouteInfo<void> {
  const ServerSelection({List<_i35.PageRouteInfo>? children})
      : super(ServerSelection.name, initialChildren: children);

  static const String name = 'ServerSelection';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i26.ServerSelection();
    },
  );
}

/// generated route for
/// [_i27.Setting]
class Setting extends _i35.PageRouteInfo<void> {
  const Setting({List<_i35.PageRouteInfo>? children})
      : super(Setting.name, initialChildren: children);

  static const String name = 'Setting';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i27.Setting();
    },
  );
}

/// generated route for
/// [_i28.SignInEmail]
class SignInEmail extends _i35.PageRouteInfo<void> {
  const SignInEmail({List<_i35.PageRouteInfo>? children})
      : super(SignInEmail.name, initialChildren: children);

  static const String name = 'SignInEmail';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i28.SignInEmail();
    },
  );
}

/// generated route for
/// [_i29.SignInPassword]
class SignInPassword extends _i35.PageRouteInfo<SignInPasswordArgs> {
  SignInPassword({
    _i36.Key? key,
    required String email,
    List<_i35.PageRouteInfo>? children,
  }) : super(
          SignInPassword.name,
          args: SignInPasswordArgs(key: key, email: email),
          initialChildren: children,
        );

  static const String name = 'SignInPassword';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SignInPasswordArgs>();
      return _i29.SignInPassword(key: args.key, email: args.email);
    },
  );
}

class SignInPasswordArgs {
  const SignInPasswordArgs({this.key, required this.email});

  final _i36.Key? key;

  final String email;

  @override
  String toString() {
    return 'SignInPasswordArgs{key: $key, email: $email}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SignInPasswordArgs) return false;
    return key == other.key && email == other.email;
  }

  @override
  int get hashCode => key.hashCode ^ email.hashCode;
}

/// generated route for
/// [_i30.SplitTunneling]
class SplitTunneling extends _i35.PageRouteInfo<void> {
  const SplitTunneling({List<_i35.PageRouteInfo>? children})
      : super(SplitTunneling.name, initialChildren: children);

  static const String name = 'SplitTunneling';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i30.SplitTunneling();
    },
  );
}

/// generated route for
/// [_i31.SplitTunnelingInfo]
class SplitTunnelingInfo extends _i35.PageRouteInfo<void> {
  const SplitTunnelingInfo({List<_i35.PageRouteInfo>? children})
      : super(SplitTunnelingInfo.name, initialChildren: children);

  static const String name = 'SplitTunnelingInfo';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i31.SplitTunnelingInfo();
    },
  );
}

/// generated route for
/// [_i32.Support]
class Support extends _i35.PageRouteInfo<void> {
  const Support({List<_i35.PageRouteInfo>? children})
      : super(Support.name, initialChildren: children);

  static const String name = 'Support';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i32.Support();
    },
  );
}

/// generated route for
/// [_i33.VPNSetting]
class VPNSetting extends _i35.PageRouteInfo<void> {
  const VPNSetting({List<_i35.PageRouteInfo>? children})
      : super(VPNSetting.name, initialChildren: children);

  static const String name = 'VPNSetting';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i33.VPNSetting();
    },
  );
}

/// generated route for
/// [_i34.WebsiteSplitTunneling]
class WebsiteSplitTunneling extends _i35.PageRouteInfo<void> {
  const WebsiteSplitTunneling({List<_i35.PageRouteInfo>? children})
      : super(WebsiteSplitTunneling.name, initialChildren: children);

  static const String name = 'WebsiteSplitTunneling';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i34.WebsiteSplitTunneling();
    },
  );
}
