// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i43;
import 'package:collection/collection.dart' as _i47;
import 'package:flutter/material.dart' as _i44;
import 'package:lantern/core/common/common.dart' as _i45;
import 'package:lantern/core/widgets/app_webview.dart' as _i3;
import 'package:lantern/features/account/account.dart' as _i1;
import 'package:lantern/features/account/delete_account.dart' as _i9;
import 'package:lantern/features/auth/add_email.dart' as _i2;
import 'package:lantern/features/auth/choose_payment_method.dart' as _i5;
import 'package:lantern/features/auth/confirm_email.dart' as _i6;
import 'package:lantern/features/auth/create_password.dart' as _i7;
import 'package:lantern/features/auth/device_limit_reached.dart' as _i11;
import 'package:lantern/features/auth/lantern_pro_license.dart' as _i18;
import 'package:lantern/features/auth/reset_password.dart' as _i31;
import 'package:lantern/features/auth/reset_password_email.dart' as _i32;
import 'package:lantern/features/auth/sign_in_email.dart' as _i35;
import 'package:lantern/features/auth/sign_in_password.dart' as _i36;
import 'package:lantern/features/developer/developer_mode.dart' as _i10;
import 'package:lantern/features/home/home.dart' as _i14;
import 'package:lantern/features/language/language.dart' as _i17;
import 'package:lantern/features/logs/logs.dart' as _i19;
import 'package:lantern/features/macos_extension/macos_extension_dialog.dart'
    as _i20;
import 'package:lantern/features/plans/plans.dart' as _i23;
import 'package:lantern/features/private_server/join_private_server.dart'
    as _i16;
import 'package:lantern/features/private_server/manage_private_server.dart'
    as _i21;
import 'package:lantern/features/private_server/manually_server_setup.dart'
    as _i22;
import 'package:lantern/features/private_server/private_server_add_billing.dart'
    as _i24;
import 'package:lantern/features/private_server/private_server_deploy.dart'
    as _i25;
import 'package:lantern/features/private_server/private_server_locations.dart'
    as _i26;
import 'package:lantern/features/private_server/private_server_setup.dart'
    as _i27;
import 'package:lantern/features/private_server/private_sever_details.dart'
    as _i28;
import 'package:lantern/features/qr_scanner/qr_code_scanner.dart' as _i29;
import 'package:lantern/features/report_Issue/report_issue.dart' as _i30;
import 'package:lantern/features/setting/download_links.dart' as _i12;
import 'package:lantern/features/setting/follow_us.dart' as _i13;
import 'package:lantern/features/setting/invite_friends.dart' as _i15;
import 'package:lantern/features/setting/setting.dart' as _i34;
import 'package:lantern/features/setting/smart_routing.dart' as _i37;
import 'package:lantern/features/setting/vpn_setting.dart' as _i41;
import 'package:lantern/features/split_tunneling/apps_split_tunneling.dart'
    as _i4;
import 'package:lantern/features/split_tunneling/default_bypass_list.dart'
    as _i8;
import 'package:lantern/features/split_tunneling/split_tunneling.dart' as _i38;
import 'package:lantern/features/split_tunneling/split_tunneling_info.dart'
    as _i39;
import 'package:lantern/features/split_tunneling/website_split_tunneling.dart'
    as _i42;
import 'package:lantern/features/support/support.dart' as _i40;
import 'package:lantern/features/vpn/server_selection.dart' as _i33;
import 'package:lantern/lantern/protos/protos/auth.pb.dart' as _i46;

/// generated route for
/// [_i1.Account]
class Account extends _i43.PageRouteInfo<void> {
  const Account({List<_i43.PageRouteInfo>? children})
      : super(Account.name, initialChildren: children);

  static const String name = 'Account';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i1.Account();
    },
  );
}

/// generated route for
/// [_i2.AddEmail]
class AddEmail extends _i43.PageRouteInfo<AddEmailArgs> {
  AddEmail({
    _i44.Key? key,
    _i45.AuthFlow authFlow = _i45.AuthFlow.signUp,
    String? password,
    List<_i43.PageRouteInfo>? children,
  }) : super(
          AddEmail.name,
          args: AddEmailArgs(key: key, authFlow: authFlow, password: password),
          initialChildren: children,
        );

  static const String name = 'AddEmail';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AddEmailArgs>(
        orElse: () => const AddEmailArgs(),
      );
      return _i2.AddEmail(
        key: args.key,
        authFlow: args.authFlow,
        password: args.password,
      );
    },
  );
}

class AddEmailArgs {
  const AddEmailArgs({
    this.key,
    this.authFlow = _i45.AuthFlow.signUp,
    this.password,
  });

  final _i44.Key? key;

  final _i45.AuthFlow authFlow;

  final String? password;

  @override
  String toString() {
    return 'AddEmailArgs{key: $key, authFlow: $authFlow, password: $password}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AddEmailArgs) return false;
    return key == other.key &&
        authFlow == other.authFlow &&
        password == other.password;
  }

  @override
  int get hashCode => key.hashCode ^ authFlow.hashCode ^ password.hashCode;
}

/// generated route for
/// [_i3.AppWebView]
class AppWebview extends _i43.PageRouteInfo<AppWebviewArgs> {
  AppWebview({
    _i44.Key? key,
    required String title,
    required String url,
    List<_i43.PageRouteInfo>? children,
  }) : super(
          AppWebview.name,
          args: AppWebviewArgs(key: key, title: title, url: url),
          initialChildren: children,
        );

  static const String name = 'AppWebview';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AppWebviewArgs>();
      return _i3.AppWebView(key: args.key, title: args.title, url: args.url);
    },
  );
}

class AppWebviewArgs {
  const AppWebviewArgs({this.key, required this.title, required this.url});

  final _i44.Key? key;

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
/// [_i4.AppsSplitTunneling]
class AppsSplitTunneling extends _i43.PageRouteInfo<void> {
  const AppsSplitTunneling({List<_i43.PageRouteInfo>? children})
      : super(AppsSplitTunneling.name, initialChildren: children);

  static const String name = 'AppsSplitTunneling';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i4.AppsSplitTunneling();
    },
  );
}

/// generated route for
/// [_i5.ChoosePaymentMethod]
class ChoosePaymentMethod extends _i43.PageRouteInfo<ChoosePaymentMethodArgs> {
  ChoosePaymentMethod({
    _i44.Key? key,
    required String email,
    String? code,
    required _i45.AuthFlow authFlow,
    List<_i43.PageRouteInfo>? children,
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

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ChoosePaymentMethodArgs>();
      return _i5.ChoosePaymentMethod(
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

  final _i44.Key? key;

  final String email;

  final String? code;

  final _i45.AuthFlow authFlow;

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
/// [_i6.ConfirmEmail]
class ConfirmEmail extends _i43.PageRouteInfo<ConfirmEmailArgs> {
  ConfirmEmail({
    _i44.Key? key,
    required String email,
    String? password,
    _i45.AuthFlow authFlow = _i45.AuthFlow.signUp,
    List<_i43.PageRouteInfo>? children,
  }) : super(
          ConfirmEmail.name,
          args: ConfirmEmailArgs(
            key: key,
            email: email,
            password: password,
            authFlow: authFlow,
          ),
          initialChildren: children,
        );

  static const String name = 'ConfirmEmail';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ConfirmEmailArgs>();
      return _i6.ConfirmEmail(
        key: args.key,
        email: args.email,
        password: args.password,
        authFlow: args.authFlow,
      );
    },
  );
}

class ConfirmEmailArgs {
  const ConfirmEmailArgs({
    this.key,
    required this.email,
    this.password,
    this.authFlow = _i45.AuthFlow.signUp,
  });

  final _i44.Key? key;

  final String email;

  final String? password;

  final _i45.AuthFlow authFlow;

  @override
  String toString() {
    return 'ConfirmEmailArgs{key: $key, email: $email, password: $password, authFlow: $authFlow}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ConfirmEmailArgs) return false;
    return key == other.key &&
        email == other.email &&
        password == other.password &&
        authFlow == other.authFlow;
  }

  @override
  int get hashCode =>
      key.hashCode ^ email.hashCode ^ password.hashCode ^ authFlow.hashCode;
}

/// generated route for
/// [_i7.CreatePassword]
class CreatePassword extends _i43.PageRouteInfo<CreatePasswordArgs> {
  CreatePassword({
    _i44.Key? key,
    required String email,
    required _i45.AuthFlow authFlow,
    required String code,
    List<_i43.PageRouteInfo>? children,
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

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CreatePasswordArgs>();
      return _i7.CreatePassword(
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

  final _i44.Key? key;

  final String email;

  final _i45.AuthFlow authFlow;

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
/// [_i8.DefaultBypassLists]
class DefaultBypassLists extends _i43.PageRouteInfo<void> {
  const DefaultBypassLists({List<_i43.PageRouteInfo>? children})
      : super(DefaultBypassLists.name, initialChildren: children);

  static const String name = 'DefaultBypassLists';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i8.DefaultBypassLists();
    },
  );
}

/// generated route for
/// [_i9.DeleteAccount]
class DeleteAccount extends _i43.PageRouteInfo<void> {
  const DeleteAccount({List<_i43.PageRouteInfo>? children})
      : super(DeleteAccount.name, initialChildren: children);

  static const String name = 'DeleteAccount';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i9.DeleteAccount();
    },
  );
}

/// generated route for
/// [_i10.DeveloperMode]
class DeveloperMode extends _i43.PageRouteInfo<void> {
  const DeveloperMode({List<_i43.PageRouteInfo>? children})
      : super(DeveloperMode.name, initialChildren: children);

  static const String name = 'DeveloperMode';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i10.DeveloperMode();
    },
  );
}

/// generated route for
/// [_i11.DeviceLimitReached]
class DeviceLimitReached extends _i43.PageRouteInfo<DeviceLimitReachedArgs> {
  DeviceLimitReached({
    _i44.Key? key,
    required List<_i46.UserResponse_Device> devices,
    List<_i43.PageRouteInfo>? children,
  }) : super(
          DeviceLimitReached.name,
          args: DeviceLimitReachedArgs(key: key, devices: devices),
          initialChildren: children,
        );

  static const String name = 'DeviceLimitReached';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DeviceLimitReachedArgs>();
      return _i11.DeviceLimitReached(key: args.key, devices: args.devices);
    },
  );
}

class DeviceLimitReachedArgs {
  const DeviceLimitReachedArgs({this.key, required this.devices});

  final _i44.Key? key;

  final List<_i46.UserResponse_Device> devices;

  @override
  String toString() {
    return 'DeviceLimitReachedArgs{key: $key, devices: $devices}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DeviceLimitReachedArgs) return false;
    return key == other.key &&
        const _i47.ListEquality<_i46.UserResponse_Device>().equals(
          devices,
          other.devices,
        );
  }

  @override
  int get hashCode =>
      key.hashCode ^
      const _i47.ListEquality<_i46.UserResponse_Device>().hash(devices);
}

/// generated route for
/// [_i12.DownloadLinks]
class DownloadLinks extends _i43.PageRouteInfo<void> {
  const DownloadLinks({List<_i43.PageRouteInfo>? children})
      : super(DownloadLinks.name, initialChildren: children);

  static const String name = 'DownloadLinks';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i12.DownloadLinks();
    },
  );
}

/// generated route for
/// [_i13.FollowUs]
class FollowUs extends _i43.PageRouteInfo<void> {
  const FollowUs({List<_i43.PageRouteInfo>? children})
      : super(FollowUs.name, initialChildren: children);

  static const String name = 'FollowUs';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i13.FollowUs();
    },
  );
}

/// generated route for
/// [_i14.Home]
class Home extends _i43.PageRouteInfo<void> {
  const Home({List<_i43.PageRouteInfo>? children})
      : super(Home.name, initialChildren: children);

  static const String name = 'Home';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i14.Home();
    },
  );
}

/// generated route for
/// [_i15.InviteFriends]
class InviteFriends extends _i43.PageRouteInfo<void> {
  const InviteFriends({List<_i43.PageRouteInfo>? children})
      : super(InviteFriends.name, initialChildren: children);

  static const String name = 'InviteFriends';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i15.InviteFriends();
    },
  );
}

/// generated route for
/// [_i16.JoinPrivateServer]
class JoinPrivateServer extends _i43.PageRouteInfo<JoinPrivateServerArgs> {
  JoinPrivateServer({
    _i44.Key? key,
    Map<String, String>? deepLinkData,
    List<_i43.PageRouteInfo>? children,
  }) : super(
          JoinPrivateServer.name,
          args: JoinPrivateServerArgs(key: key, deepLinkData: deepLinkData),
          initialChildren: children,
        );

  static const String name = 'JoinPrivateServer';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<JoinPrivateServerArgs>(
        orElse: () => const JoinPrivateServerArgs(),
      );
      return _i16.JoinPrivateServer(
        key: args.key,
        deepLinkData: args.deepLinkData,
      );
    },
  );
}

class JoinPrivateServerArgs {
  const JoinPrivateServerArgs({this.key, this.deepLinkData});

  final _i44.Key? key;

  final Map<String, String>? deepLinkData;

  @override
  String toString() {
    return 'JoinPrivateServerArgs{key: $key, deepLinkData: $deepLinkData}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! JoinPrivateServerArgs) return false;
    return key == other.key &&
        const _i47.MapEquality<String, String>().equals(
          deepLinkData,
          other.deepLinkData,
        );
  }

  @override
  int get hashCode =>
      key.hashCode ^
      const _i47.MapEquality<String, String>().hash(deepLinkData);
}

/// generated route for
/// [_i17.Language]
class Language extends _i43.PageRouteInfo<void> {
  const Language({List<_i43.PageRouteInfo>? children})
      : super(Language.name, initialChildren: children);

  static const String name = 'Language';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i17.Language();
    },
  );
}

/// generated route for
/// [_i18.LanternProLicense]
class LanternProLicense extends _i43.PageRouteInfo<LanternProLicenseArgs> {
  LanternProLicense({
    _i44.Key? key,
    required String email,
    required String code,
    List<_i43.PageRouteInfo>? children,
  }) : super(
          LanternProLicense.name,
          args: LanternProLicenseArgs(key: key, email: email, code: code),
          initialChildren: children,
        );

  static const String name = 'LanternProLicense';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LanternProLicenseArgs>();
      return _i18.LanternProLicense(
        key: args.key,
        email: args.email,
        code: args.code,
      );
    },
  );
}

class LanternProLicenseArgs {
  const LanternProLicenseArgs({
    this.key,
    required this.email,
    required this.code,
  });

  final _i44.Key? key;

  final String email;

  final String code;

  @override
  String toString() {
    return 'LanternProLicenseArgs{key: $key, email: $email, code: $code}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LanternProLicenseArgs) return false;
    return key == other.key && email == other.email && code == other.code;
  }

  @override
  int get hashCode => key.hashCode ^ email.hashCode ^ code.hashCode;
}

/// generated route for
/// [_i19.Logs]
class Logs extends _i43.PageRouteInfo<void> {
  const Logs({List<_i43.PageRouteInfo>? children})
      : super(Logs.name, initialChildren: children);

  static const String name = 'Logs';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i19.Logs();
    },
  );
}

/// generated route for
/// [_i20.MacOSExtensionDialog]
class MacOSExtensionDialog extends _i43.PageRouteInfo<void> {
  const MacOSExtensionDialog({List<_i43.PageRouteInfo>? children})
      : super(MacOSExtensionDialog.name, initialChildren: children);

  static const String name = 'MacOSExtensionDialog';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i20.MacOSExtensionDialog();
    },
  );
}

/// generated route for
/// [_i21.ManagePrivateServer]
class ManagePrivateServer extends _i43.PageRouteInfo<void> {
  const ManagePrivateServer({List<_i43.PageRouteInfo>? children})
      : super(ManagePrivateServer.name, initialChildren: children);

  static const String name = 'ManagePrivateServer';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i21.ManagePrivateServer();
    },
  );
}

/// generated route for
/// [_i22.ManuallyServerSetup]
class ManuallyServerSetup extends _i43.PageRouteInfo<void> {
  const ManuallyServerSetup({List<_i43.PageRouteInfo>? children})
      : super(ManuallyServerSetup.name, initialChildren: children);

  static const String name = 'ManuallyServerSetup';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i22.ManuallyServerSetup();
    },
  );
}

/// generated route for
/// [_i23.Plans]
class Plans extends _i43.PageRouteInfo<void> {
  const Plans({List<_i43.PageRouteInfo>? children})
      : super(Plans.name, initialChildren: children);

  static const String name = 'Plans';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i23.Plans();
    },
  );
}

/// generated route for
/// [_i24.PrivateServerAddBilling]
class PrivateServerAddBilling extends _i43.PageRouteInfo<void> {
  const PrivateServerAddBilling({List<_i43.PageRouteInfo>? children})
      : super(PrivateServerAddBilling.name, initialChildren: children);

  static const String name = 'PrivateServerAddBilling';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i24.PrivateServerAddBilling();
    },
  );
}

/// generated route for
/// [_i25.PrivateServerDeploy]
class PrivateServerDeploy extends _i43.PageRouteInfo<PrivateServerDeployArgs> {
  PrivateServerDeploy({
    _i44.Key? key,
    required String serverName,
    List<_i43.PageRouteInfo>? children,
  }) : super(
          PrivateServerDeploy.name,
          args: PrivateServerDeployArgs(key: key, serverName: serverName),
          initialChildren: children,
        );

  static const String name = 'PrivateServerDeploy';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PrivateServerDeployArgs>();
      return _i25.PrivateServerDeploy(
        key: args.key,
        serverName: args.serverName,
      );
    },
  );
}

class PrivateServerDeployArgs {
  const PrivateServerDeployArgs({this.key, required this.serverName});

  final _i44.Key? key;

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
/// [_i26.PrivateServerLocation]
class PrivateServerLocation
    extends _i43.PageRouteInfo<PrivateServerLocationArgs> {
  PrivateServerLocation({
    _i44.Key? key,
    required List<String> location,
    required String? selectedLocation,
    required dynamic Function(String) onLocationSelected,
    required _i45.CloudProvider provider,
    List<_i43.PageRouteInfo>? children,
  }) : super(
          PrivateServerLocation.name,
          args: PrivateServerLocationArgs(
            key: key,
            location: location,
            selectedLocation: selectedLocation,
            onLocationSelected: onLocationSelected,
            provider: provider,
          ),
          initialChildren: children,
        );

  static const String name = 'PrivateServerLocation';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PrivateServerLocationArgs>();
      return _i26.PrivateServerLocation(
        key: args.key,
        location: args.location,
        selectedLocation: args.selectedLocation,
        onLocationSelected: args.onLocationSelected,
        provider: args.provider,
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
    required this.provider,
  });

  final _i44.Key? key;

  final List<String> location;

  final String? selectedLocation;

  final dynamic Function(String) onLocationSelected;

  final _i45.CloudProvider provider;

  @override
  String toString() {
    return 'PrivateServerLocationArgs{key: $key, location: $location, selectedLocation: $selectedLocation, onLocationSelected: $onLocationSelected, provider: $provider}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PrivateServerLocationArgs) return false;
    return key == other.key &&
        const _i47.ListEquality<String>().equals(location, other.location) &&
        selectedLocation == other.selectedLocation &&
        provider == other.provider;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      const _i47.ListEquality<String>().hash(location) ^
      selectedLocation.hashCode ^
      provider.hashCode;
}

/// generated route for
/// [_i27.PrivateServerSetup]
class PrivateServerSetup extends _i43.PageRouteInfo<void> {
  const PrivateServerSetup({List<_i43.PageRouteInfo>? children})
      : super(PrivateServerSetup.name, initialChildren: children);

  static const String name = 'PrivateServerSetup';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i27.PrivateServerSetup();
    },
  );
}

/// generated route for
/// [_i28.PrivateSeverDetails]
class PrivateServerDetails
    extends _i43.PageRouteInfo<PrivateServerDetailsArgs> {
  PrivateServerDetails({
    _i44.Key? key,
    required List<String> accounts,
    required _i45.CloudProvider provider,
    bool isPreFilled = false,
    List<_i43.PageRouteInfo>? children,
  }) : super(
          PrivateServerDetails.name,
          args: PrivateServerDetailsArgs(
            key: key,
            accounts: accounts,
            provider: provider,
            isPreFilled: isPreFilled,
          ),
          initialChildren: children,
        );

  static const String name = 'PrivateServerDetails';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PrivateServerDetailsArgs>();
      return _i28.PrivateSeverDetails(
        key: args.key,
        accounts: args.accounts,
        provider: args.provider,
        isPreFilled: args.isPreFilled,
      );
    },
  );
}

class PrivateServerDetailsArgs {
  const PrivateServerDetailsArgs({
    this.key,
    required this.accounts,
    required this.provider,
    this.isPreFilled = false,
  });

  final _i44.Key? key;

  final List<String> accounts;

  final _i45.CloudProvider provider;

  final bool isPreFilled;

  @override
  String toString() {
    return 'PrivateServerDetailsArgs{key: $key, accounts: $accounts, provider: $provider, isPreFilled: $isPreFilled}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PrivateServerDetailsArgs) return false;
    return key == other.key &&
        const _i47.ListEquality<String>().equals(accounts, other.accounts) &&
        provider == other.provider &&
        isPreFilled == other.isPreFilled;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      const _i47.ListEquality<String>().hash(accounts) ^
      provider.hashCode ^
      isPreFilled.hashCode;
}

/// generated route for
/// [_i29.QrCodeScanner]
class QrCodeScanner extends _i43.PageRouteInfo<QrCodeScannerArgs> {
  QrCodeScanner({_i44.Key? key, List<_i43.PageRouteInfo>? children})
      : super(
          QrCodeScanner.name,
          args: QrCodeScannerArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'QrCodeScanner';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<QrCodeScannerArgs>(
        orElse: () => const QrCodeScannerArgs(),
      );
      return _i29.QrCodeScanner(key: args.key);
    },
  );
}

class QrCodeScannerArgs {
  const QrCodeScannerArgs({this.key});

  final _i44.Key? key;

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
/// [_i30.ReportIssue]
class ReportIssue extends _i43.PageRouteInfo<ReportIssueArgs> {
  ReportIssue({
    _i44.Key? key,
    String? description,
    String? type,
    List<_i43.PageRouteInfo>? children,
  }) : super(
          ReportIssue.name,
          args: ReportIssueArgs(key: key, description: description, type: type),
          initialChildren: children,
        );

  static const String name = 'ReportIssue';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ReportIssueArgs>(
        orElse: () => const ReportIssueArgs(),
      );
      return _i30.ReportIssue(
        key: args.key,
        description: args.description,
        type: args.type,
      );
    },
  );
}

class ReportIssueArgs {
  const ReportIssueArgs({this.key, this.description, this.type});

  final _i44.Key? key;

  final String? description;

  final String? type;

  @override
  String toString() {
    return 'ReportIssueArgs{key: $key, description: $description, type: $type}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ReportIssueArgs) return false;
    return key == other.key &&
        description == other.description &&
        type == other.type;
  }

  @override
  int get hashCode => key.hashCode ^ description.hashCode ^ type.hashCode;
}

/// generated route for
/// [_i31.ResetPassword]
class ResetPassword extends _i43.PageRouteInfo<ResetPasswordArgs> {
  ResetPassword({
    _i44.Key? key,
    required String email,
    required String code,
    List<_i43.PageRouteInfo>? children,
  }) : super(
          ResetPassword.name,
          args: ResetPasswordArgs(key: key, email: email, code: code),
          initialChildren: children,
        );

  static const String name = 'ResetPassword';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ResetPasswordArgs>();
      return _i31.ResetPassword(
        key: args.key,
        email: args.email,
        code: args.code,
      );
    },
  );
}

class ResetPasswordArgs {
  const ResetPasswordArgs({this.key, required this.email, required this.code});

  final _i44.Key? key;

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
/// [_i32.ResetPasswordEmail]
class ResetPasswordEmail extends _i43.PageRouteInfo<ResetPasswordEmailArgs> {
  ResetPasswordEmail({
    _i44.Key? key,
    String? email,
    List<_i43.PageRouteInfo>? children,
  }) : super(
          ResetPasswordEmail.name,
          args: ResetPasswordEmailArgs(key: key, email: email),
          initialChildren: children,
        );

  static const String name = 'ResetPasswordEmail';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ResetPasswordEmailArgs>(
        orElse: () => const ResetPasswordEmailArgs(),
      );
      return _i32.ResetPasswordEmail(key: args.key, email: args.email);
    },
  );
}

class ResetPasswordEmailArgs {
  const ResetPasswordEmailArgs({this.key, this.email});

  final _i44.Key? key;

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
/// [_i33.ServerSelection]
class ServerSelection extends _i43.PageRouteInfo<void> {
  const ServerSelection({List<_i43.PageRouteInfo>? children})
      : super(ServerSelection.name, initialChildren: children);

  static const String name = 'ServerSelection';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i33.ServerSelection();
    },
  );
}

/// generated route for
/// [_i34.Setting]
class Setting extends _i43.PageRouteInfo<void> {
  const Setting({List<_i43.PageRouteInfo>? children})
      : super(Setting.name, initialChildren: children);

  static const String name = 'Setting';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i34.Setting();
    },
  );
}

/// generated route for
/// [_i35.SignInEmail]
class SignInEmail extends _i43.PageRouteInfo<void> {
  const SignInEmail({List<_i43.PageRouteInfo>? children})
      : super(SignInEmail.name, initialChildren: children);

  static const String name = 'SignInEmail';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i35.SignInEmail();
    },
  );
}

/// generated route for
/// [_i36.SignInPassword]
class SignInPassword extends _i43.PageRouteInfo<SignInPasswordArgs> {
  SignInPassword({
    _i44.Key? key,
    required String email,
    bool fromChangeEmail = false,
    List<_i43.PageRouteInfo>? children,
  }) : super(
          SignInPassword.name,
          args: SignInPasswordArgs(
            key: key,
            email: email,
            fromChangeEmail: fromChangeEmail,
          ),
          initialChildren: children,
        );

  static const String name = 'SignInPassword';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SignInPasswordArgs>();
      return _i36.SignInPassword(
        key: args.key,
        email: args.email,
        fromChangeEmail: args.fromChangeEmail,
      );
    },
  );
}

class SignInPasswordArgs {
  const SignInPasswordArgs({
    this.key,
    required this.email,
    this.fromChangeEmail = false,
  });

  final _i44.Key? key;

  final String email;

  final bool fromChangeEmail;

  @override
  String toString() {
    return 'SignInPasswordArgs{key: $key, email: $email, fromChangeEmail: $fromChangeEmail}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SignInPasswordArgs) return false;
    return key == other.key &&
        email == other.email &&
        fromChangeEmail == other.fromChangeEmail;
  }

  @override
  int get hashCode => key.hashCode ^ email.hashCode ^ fromChangeEmail.hashCode;
}

/// generated route for
/// [_i37.SmartRouting]
class SmartRouting extends _i43.PageRouteInfo<void> {
  const SmartRouting({List<_i43.PageRouteInfo>? children})
      : super(SmartRouting.name, initialChildren: children);

  static const String name = 'SmartRouting';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i37.SmartRouting();
    },
  );
}

/// generated route for
/// [_i38.SplitTunneling]
class SplitTunneling extends _i43.PageRouteInfo<void> {
  const SplitTunneling({List<_i43.PageRouteInfo>? children})
      : super(SplitTunneling.name, initialChildren: children);

  static const String name = 'SplitTunneling';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i38.SplitTunneling();
    },
  );
}

/// generated route for
/// [_i39.SplitTunnelingInfo]
class SplitTunnelingInfo extends _i43.PageRouteInfo<void> {
  const SplitTunnelingInfo({List<_i43.PageRouteInfo>? children})
      : super(SplitTunnelingInfo.name, initialChildren: children);

  static const String name = 'SplitTunnelingInfo';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i39.SplitTunnelingInfo();
    },
  );
}

/// generated route for
/// [_i40.Support]
class Support extends _i43.PageRouteInfo<void> {
  const Support({List<_i43.PageRouteInfo>? children})
      : super(Support.name, initialChildren: children);

  static const String name = 'Support';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i40.Support();
    },
  );
}

/// generated route for
/// [_i41.VPNSetting]
class VPNSetting extends _i43.PageRouteInfo<void> {
  const VPNSetting({List<_i43.PageRouteInfo>? children})
      : super(VPNSetting.name, initialChildren: children);

  static const String name = 'VPNSetting';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i41.VPNSetting();
    },
  );
}

/// generated route for
/// [_i42.WebsiteSplitTunneling]
class WebsiteSplitTunneling extends _i43.PageRouteInfo<void> {
  const WebsiteSplitTunneling({List<_i43.PageRouteInfo>? children})
      : super(WebsiteSplitTunneling.name, initialChildren: children);

  static const String name = 'WebsiteSplitTunneling';

  static _i43.PageInfo page = _i43.PageInfo(
    name,
    builder: (data) {
      return const _i42.WebsiteSplitTunneling();
    },
  );
}
