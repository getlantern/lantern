import 'package:lantern/features/account/account.dart';
import 'package:lantern/features/account/delete_account.dart';
import 'package:lantern/features/home/new_home.dart';
import 'package:lantern/features/language/language.dart';
import 'package:lantern/features/reportIssue/report_issue.dart';
import 'package:lantern/features/setting/download_links.dart';
import 'package:lantern/features/setting/invite_friends.dart';
import 'package:lantern/features/setting/setting.dart';
import 'package:lantern/features/setting/vpn_setting.dart';

class AppRoutes {
  static const String home = '/';
  static const String setting = '/setting';
  static const String language = '/language';
  static const String reportIssue = '/report-issue';
  static const String downloadLinks = '/download-links';
  static const String inviteFriends = '/invite-friends';
  static const String vpnSetting = '/vpn-setting';
  static const String account = '/account';
  static const String deleteAccount = '/delete-account';
}

final routes = {
  AppRoutes.home: (context) => NewHome(),
  AppRoutes.setting: (context) => Setting(),
  AppRoutes.language: (context) => Language(),
  AppRoutes.reportIssue: (context) => ReportIssue(),
  AppRoutes.downloadLinks: (context) => DownloadLinks(),
  AppRoutes.inviteFriends: (context) => InviteFriends(),
  AppRoutes.vpnSetting: (context) => VPNSetting(),
  AppRoutes.account: (context) => Account(),
  AppRoutes.deleteAccount: (context) => DeleteAccount(),
};
