import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/features/user_message/user_message_route_observer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../helpers/provider/helpers_notifier.dart';
import '../home/provider/app_setting_notifier.dart';
import '../home/provider/feature_flag_notifier.dart';
import 'action_mode_page.dart';
import 'onboarding.dart';

part 'personal_proxies_intro.g.dart';

/// Where Action Mode is offered: where Home shows its tab.
@riverpod
bool actionModeOffered(Ref ref) =>
    ref.watch(
      featureFlagProvider.select((f) => f.getBool(FeatureFlag.unbounded)),
    ) &&
    !ref.watch(appSettingProvider.select((s) => s.unboundedHidden));

/// The pages that introduce Personal Proxies to this user: What makes
/// Lantern different with its Personal Proxies row where helper invites are
/// offered, and the Action Mode page with Help someone you know where Action
/// Mode is offered in a build with helper invites. Neither, and there is
/// nothing new to introduce.
typedef PersonalProxiesIntroPages = ({bool invites, bool actionMode});

@riverpod
PersonalProxiesIntroPages personalProxiesIntroPages(Ref ref) => (
  invites: ref.watch(helperInvitesAvailableProvider),
  actionMode:
      HelpersNotifier.buildEnabled && ref.watch(actionModeOfferedProvider),
);

/// Opens the Personal Proxies introduction over Home once, for a user who
/// finished onboarding without it, while the personal_proxies_intro flag is
/// on. Flags can land after the first frame, so it watches them rather than
/// looking once. It waits while anything covers Home ([routes] says when
/// that changes), and leaves a launch that opens the macOS system extension
/// dialog alone: the next launch shows it.
void usePersonalProxiesIntro(
  BuildContext context,
  WidgetRef ref,
  UserMessageRouteObserver routes,
) {
  final route = ModalRoute.of(context);
  final pushed = useRef(false);
  final extensionDialogLaunch = useMemoized(
    () =>
        PlatformUtils.isMacOS && ref.read(appSettingProvider).showSplashScreen,
  );

  useEffect(() {
    if (extensionDialogLaunch) return null;
    var scheduled = false;

    void open() {
      if (!context.mounted || pushed.value) return;
      final setting = ref.read(appSettingProvider);
      if (!setting.onboardingCompleted || setting.personalProxiesIntroSeen) {
        return;
      }
      final flags = ref.read(featureFlagProvider);
      if (!flags.getBool(FeatureFlag.personalProxiesIntro)) return;
      final pages = ref.read(personalProxiesIntroPagesProvider);
      if (!pages.invites && !pages.actionMode) return;
      if (!(route?.isCurrent ?? false)) return;
      pushed.value = true;
      // Seen once opened, so a crash or a kill does not bring it back.
      ref.read(appSettingProvider.notifier).setPersonalProxiesIntroSeen(true);
      appLogger.info('Showing the Personal Proxies introduction');
      appRouter.push(
        PersonalProxiesIntro(
          invites: pages.invites,
          actionMode: pages.actionMode,
        ),
      );
    }

    void schedule() {
      if (scheduled) return;
      scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scheduled = false;
        open();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }

    final subs = [
      ref.listenManual(
        featureFlagProvider.select(
          (f) => f.getBool(FeatureFlag.personalProxiesIntro),
        ),
        (_, _) => schedule(),
        fireImmediately: true,
      ),
      ref.listenManual(personalProxiesIntroPagesProvider, (_, _) => schedule()),
      ref.listenManual(
        appSettingProvider.select((s) => s.onboardingCompleted),
        (_, _) => schedule(),
      ),
    ];
    routes.changes.addListener(schedule);
    return () {
      for (final sub in subs) {
        sub.close();
      }
      routes.changes.removeListener(schedule);
    };
  }, [routes]);
}

/// Introduces Personal Proxies to a user who finished onboarding before it
/// did, with onboarding's own pages: What makes Lantern different where
/// [invites], then the Action Mode page where [actionMode]. It only
/// explains: nothing here turns Action Mode on or creates an invite.
@RoutePage(name: 'PersonalProxiesIntro')
class PersonalProxiesIntroScreen extends HookWidget {
  const PersonalProxiesIntroScreen({
    super.key,
    required this.invites,
    required this.actionMode,
  });

  final bool invites;
  final bool actionMode;

  @override
  Widget build(BuildContext context) {
    final controller = useState(FlutterCarouselController());
    final pageIndex = useState(0);
    final pages = <Widget>[
      if (invites) const OnboardingDifferentPage(personalProxies: true),
      if (actionMode) const OnboardingActionModePage(),
    ];
    final lastPage = pageIndex.value >= pages.length - 1;

    return Scaffold(
      key: const Key('personal_proxies_intro.screen'),
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        backgroundColor: context.bgElevated,
        title: LanternLogo(color: context.textPrimary),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0),
          child: DividerSpace(padding: EdgeInsets.zero),
        ),
      ),
      body: Container(
        color: context.bgElevated,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: pages.length < 2
                    ? pages.firstOrNull ?? const SizedBox.shrink()
                    : FlutterCarousel(
                        options: FlutterCarouselOptions(
                          onPageChanged: (index, reason) {
                            pageIndex.value = index;
                          },
                          controller: controller.value,
                          height: double.infinity,
                          viewportFraction: 1.0,
                          showIndicator: true,
                          pageSnapping: true,
                          floatingIndicator: true,
                          slideIndicator: CircularSlideIndicator(
                            slideIndicatorOptions: SlideIndicatorOptions(
                              indicatorRadius: 5,
                              itemSpacing: 15,
                              indicatorBorderWidth: 0.0,
                              currentIndicatorColor: AppColors.blue3,
                              indicatorBackgroundColor: context.borderInput,
                              enableAnimation: true,
                              padding: EdgeInsets.only(bottom: 10.0),
                              alignment: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        items: pages,
                      ),
              ),
              PrimaryButton(
                key: const Key('personal_proxies_intro.primary'),
                label: lastPage ? 'got_it'.i18n : 'continue'.i18n,
                isTaller: true,
                onPressed: () {
                  if (lastPage) {
                    appRouter.pop();
                    return;
                  }
                  controller.value.nextPage();
                },
              ),
              SizedBox(height: 28.0),
            ],
          ),
        ),
      ),
    );
  }
}
