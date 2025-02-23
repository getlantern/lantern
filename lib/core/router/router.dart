import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lantern/features/account/account.dart';
import 'package:lantern/features/account/delete_account.dart';
import 'package:lantern/features/home/new_home.dart';
import 'package:lantern/features/language/language.dart';
import 'package:lantern/features/reportIssue/report_issue.dart';
import 'package:lantern/features/setting/download_links.dart';
import 'package:lantern/features/setting/invite_friends.dart';
import 'package:lantern/features/setting/setting.dart';
import 'package:lantern/features/setting/vpn_setting.dart';

part 'router.g.dart';

@TypedGoRoute<HomeRoute>(path: '/', routes: [
  TypedGoRoute<HomeRoute>(
    path: '/',
  ),
  TypedGoRoute<SettingRoute>(
    path: '/setting',
  ),
  TypedGoRoute<LanguageRoute>(
    path: '/language',
  ),
  TypedGoRoute<ReportIssueRoute>(
    path: '/report-issue',
  ),
  TypedGoRoute<DownloadLinksRoute>(
    path: '/download',
  ),
  TypedGoRoute<InviteFriendsRoute>(
    path: '/invite-friends',
  ),
  TypedGoRoute<VPNSettingRoute>(
    path: '/vpn-setting',
  ),
  TypedGoRoute<AccountRoute>(
    path: '/account',
  ),
  TypedGoRoute<DeleteAccountRoute>(
    path: '/delete-account',
  ),
])
@immutable
class HomeRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) => const NewHome();
}

@immutable
class SettingRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) => const Setting();
}

@immutable
class LanguageRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) => const Language();
}

@immutable
class ReportIssueRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ReportIssue();
}

@immutable
class DownloadLinksRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DownloadLinks();
}

@immutable
class InviteFriendsRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const InviteFriends();
}

@immutable
class VPNSettingRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) => const VPNSetting();
}

@immutable
class AccountRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) => const Account();
}

@immutable
class DeleteAccountRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DeleteAccount();
}
