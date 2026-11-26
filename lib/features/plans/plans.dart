import 'dart:io';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/tv_shell.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/telemetry/telemetry.dart';
import 'package:lantern/core/utils/screen_utils.dart';
import 'package:lantern/core/widgets/app_rich_text.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/country_code_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/plans/feature_list.dart';
import 'package:lantern/features/plans/plans_list.dart';
import 'package:lantern/features/plans/provider/payment_notifier.dart';
import 'package:lantern/features/plans/provider/plans_notifier.dart';
import 'package:lantern/features/plans/provider/referral_notifier.dart';
import 'package:lantern/features/plans/restore_purchase_mixin.dart';

import '../../core/models/plan_data.dart';
import '../../core/models/referral_attach_response.dart';

/// TV layout (Figma "Android TV / Plans (full screen)"): the "why upgrade"
/// column and the gap before the plans column, inside the 48dp margins.
const double _tvWhyUpgradeWidth = 380;
const double _tvColumnGap = 64;

@RoutePage(name: 'Plans')
class Plans extends StatefulHookConsumerWidget {
  const Plans({super.key, this.referralCode});

  /// Referral/affiliate code delivered via a deep link
  /// (https://lantern.io/affiliate/<code>); applied automatically on open.
  final String? referralCode;

  @override
  ConsumerState<Plans> createState() => _PlansState();
}

class _PlansState extends ConsumerState<Plans>
    with RestorePurchaseMixin<Plans> {
  late TextTheme textTheme;

  /// TV: "Get Lantern Pro" takes the first focus once the plans have loaded,
  /// so buying the preselected plan is one press.
  final _tvCtaFocus = FocusNode(debugLabel: 'plans.cta');
  final _tvRetryFocus = FocusNode(debugLabel: 'plans.retry');
  final _tvPromoFocus = FocusNode(debugLabel: 'plans.promo_code');
  final _tvLicenseFocus = FocusNode(debugLabel: 'plans.license');

  /// The control this screen last gave focus to on its own; focus still
  /// there counts as not moved by the viewer. Cleared when it loses focus,
  /// so a viewer who left and came back owns it.
  FocusNode? _tvPlacedFocus;

  void _tvPlacedFocusChanged() {
    final placed = _tvPlacedFocus;
    if (placed == null) return;
    if (!placed.hasFocus) {
      placed.removeListener(_tvPlacedFocusChanged);
      _tvPlacedFocus = null;
    }
  }

  @override
  void dispose() {
    _tvCtaFocus.dispose();
    _tvPlacedFocus?.removeListener(_tvPlacedFocusChanged);
    _tvRetryFocus.dispose();
    _tvPromoFocus.dispose();
    _tvLicenseFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final code = widget.referralCode;
    if (code != null && code.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _applyDeepLinkCode(code),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Billing availability changes when the country-code event arrives.
    ref.watch(countryCodeProvider);
    textTheme = Theme.of(context).textTheme;
    if (PlatformUtils.tvShellEnabled && AppBuildInfo.enablePayments) {
      return _buildTvScreen();
    }
    return BaseScreen(
      backgroundColor: context.bgElevated,
      padded: false,
      resizeToAvoidBottomInset: false,
      appBar: CustomAppBar(
        title: SizedBox(
          height: 20.h,
          child: LanternLogo(color: context.textPrimary, isPro: true),
        ),
        backgroundColor: context.bgElevated,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () {
            appRouter.maybePop();
          },
        ),
        actions: [
          if (AppBuildInfo.enablePayments)
            IconButton(icon: Icon(Icons.more_vert), onPressed: onMenuTap),
        ],
      ),
      title: "",
      body: SafeArea(bottom: !PlatformUtils.isIOS, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (!AppBuildInfo.enablePayments) return _buildLicenseOnlyBody();
    final plansState = ref.watch(plansProvider);
    return Column(
      children: [
        // Features fill whatever space the bottom section leaves, centered.
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: defaultSize),
            child: Center(child: FeatureList()),
          ),
        ),
        SizedBox(height: defaultSize),
        DividerSpace(padding: EdgeInsets.zero),
        // Bottom section sizes to its content: plans, then the CTA button.
        Container(
          color: context.bgSurface,
          padding: EdgeInsets.symmetric(
            horizontal: context.isSmallDevice ? 0 : defaultSize,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(height: 10),
              _buildAffiliateBanner(),
              Padding(
                padding: EdgeInsets.only(left: context.isSmallDevice ? 16 : 0),
                child: _plansListOrStatus(plansState),
              ),
              SizedBox(height: defaultSize),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.isSmallDevice ? defaultSize : 0,
                ),
                child: PrimaryButton(
                  buttonKey: const Key('plans.cta'),
                  label: 'get_lantern_pro'.i18n,
                  isTaller: true,
                  enabled:
                      !plansState.hasError &&
                      (plansState.value?.plans.isNotEmpty ?? false),
                  onPressed: onGetLanternProTap,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: sl<AppPurchase>().productsLoaded,
                builder: (context, _, _) {
                  if (!sl<AppPurchase>().isStoreBillingAvailable) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: AppRichText(
                        key: const Key('plans.restore'),
                        texts: '${'already_purchased'.i18n} ',
                        boldTexts: 'restore_purchase'.i18n,
                        boldUnderline: true,
                        boldOnPressed: _restorePurchaseFlow,
                      ),
                    ),
                  );
                },
              ),
              if (PlatformUtils.isIOS) ...{
                SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    'subscription_renewal_info'.i18n,
                    style: textTheme.labelMedium!.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                ),
                IntrinsicHeight(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      AppTextButton(
                        label: 'privacy_policy'.i18n,
                        fontSize: 12,
                        textColor: context.textTertiary,
                        onPressed: () {
                          UrlUtils.openWithSystemBrowser(AppUrls.privacyPolicy);
                        },
                      ),
                      VerticalDivider(indent: 10, endIndent: 10),
                      AppTextButton(
                        label: 'terms_of_service'.i18n,
                        fontSize: 12,
                        textColor: context.textTertiary,
                        onPressed: () {
                          UrlUtils.openWithSystemBrowser(
                            AppUrls.termsOfService,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              },
              SizedBox(height: size24),
            ],
          ),
        ),
      ],
    );
  }

  /// The plan cards, or the loading or error state in their place. On TV
  /// the cards take [cardWidth] for their badge, and Retry is a button the
  /// screen can give focus to.
  Widget _plansListOrStatus(
    AsyncValue<PlansData> plansState, {
    double? cardWidth,
  }) {
    return plansState.when(
      // An empty list is a failed fetch too, with the same Retry.
      data: (data) => data.plans.isEmpty
          ? _plansFetchError()
          : PlansListView(data: data, cardWidth: cardWidth),
      loading: () => Center(child: LoadingIndicator()),
      error: (_, _) => _plansFetchError(),
    );
  }

  Widget _plansFetchError() {
    void retry() => ref.read(plansProvider.notifier).retryFetchPlans();
    return Column(
      children: [
        Text('plans_fetch_error'.i18n, style: textTheme.labelLarge),
        if (PlatformUtils.tvShellEnabled)
          PrimaryButton(
            buttonKey: const Key('plans.retry'),
            focusNode: _tvRetryFocus,
            label: 'retry'.i18n,
            onPressed: retry,
          )
        else
          AppTextButton(label: 'retry'.i18n, onPressed: retry),
      ],
    );
  }

  /// The TV screen (Figma "Android TV / Plans (full screen)"): the whole
  /// 960x540 inside the safe margins. Left, not focusable: the Lantern Pro
  /// logo and the benefits, giving way on a narrower or shorter TV. Right:
  /// the plan cards, "Get Lantern Pro", then the menu's items as links,
  /// scrolling by focus when they do not fit. The close button sits top
  /// left. Focus is this screen's own (it takes the whole screen, outside
  /// TvShell) and follows the one state the cards render: the first link
  /// while they load, Retry on a load error, "Get Lantern Pro" once they
  /// show; it is never taken from a viewer who moved it, nor while a
  /// dialog covers the screen. The button does what it does on a phone.
  /// The one control the phone's body has and TV does not is Restore
  /// Purchase (under the button when store billing is available); on TV
  /// it stays in Settings, which offers it, as on a phone, to accounts that
  /// are not Pro.
  Widget _buildTvScreen() {
    final plansState = ref.watch(plansProvider);
    // Ready means the cards are showing: a value kept while a refetch
    // runs is not, since the list shows its loading state then.
    final plansReady = _tvPlansReady(plansState);
    final isReferralApplied = ref.watch(referralProvider).isApplied;
    // Every build: a no-op while the viewer holds a control of this screen
    // (see _tvInitialFocus), and the way back whenever nothing does, such
    // as after a control that had focus left the screen.
    _tvInitialFocus(_tvFocusTargetFor(plansState, isReferralApplied));
    final textDirection = Directionality.of(context);
    // Back and Close wait for a running checkout, which owns the app-wide
    // loading overlay; a second press leaves one that never settles.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_tvStoreBusy) {
          if (!_tvLeaveWhileBusy) {
            _tvLeaveWhileBusy = true;
            return;
          }
          context.hideLoadingDialog();
        }
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: context.bgElevated,
        // The columns are sized to the screen and cannot give way to the
        // on-screen keyboard; a dialog that opens it handles its own inset.
        resizeToAvoidBottomInset: false,
        // Reading order with the shell's reveal, so a D-pad move scrolls
        // the focused control into the safe area as on shell screens.
        body: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(
            requestFocusCallback: tvRequestFocus,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: tvSafeMarginH,
              vertical: tvSafeMarginV,
            ),
            child: Stack(
              // The close button's ring reaches past the safe margin's corner.
              clipBehavior: Clip.none,
              children: [
                // The columns keep their physical places in right-to-left
                // locales, as TvShell's panels do (the close button is on the
                // physical left); text keeps its direction. The benefits take
                // at most their design width and give way on a narrower TV,
                // and the right column scrolls by focus when it does not fit.
                LayoutBuilder(
                  builder: (context, constraints) => Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: math.min(
                            _tvWhyUpgradeWidth,
                            constraints.maxWidth * 0.42,
                          ),
                          child: ExcludeFocus(
                            child: Directionality(
                              textDirection: textDirection,
                              // Clips rather than overflows on a short TV;
                              // it holds nothing a remote can reach.
                              child: SingleChildScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 80),
                                    Padding(
                                      // Lines the logo up with the benefit icons.
                                      padding: const EdgeInsetsDirectional.only(
                                        start: defaultSize,
                                      ),
                                      child: AppImage(
                                        path: AppImagePaths.lanternPro,
                                        color: context.textPrimary,
                                        width: 246,
                                        height: 32,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                    const FeatureList(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: _tvColumnGap),
                        Expanded(
                          child: Directionality(
                            textDirection: textDirection,
                            child: SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildAffiliateBanner(),
                                    // The cards place their Best Value badge from the
                                    // card's own width here (the phone's from the
                                    // viewport), so the list's layout rule is untouched.
                                    LayoutBuilder(
                                      builder: (context, constraints) =>
                                          _plansListOrStatus(
                                            plansState,
                                            cardWidth:
                                                constraints.maxWidth +
                                                2 * defaultSize,
                                          ),
                                    ),
                                    const SizedBox(height: 28),
                                    PrimaryButton(
                                      buttonKey: const Key('plans.cta'),
                                      focusNode: _tvCtaFocus,
                                      label: 'get_lantern_pro'.i18n,
                                      enabled: plansReady,
                                      onPressed: _tvGetLanternPro,
                                    ),
                                    const SizedBox(height: 20),
                                    // The three-dot menu's items, as links a
                                    // remote can reach. No Restore Purchase: a
                                    // second store operation the remote could
                                    // stack on a checkout. Settings keeps it.
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      spacing: defaultSize,
                                      runSpacing: 8,
                                      children: [
                                        if (!isReferralApplied)
                                          AppTextButton(
                                            key: const Key('plans.promo_code'),
                                            focusNode: _tvPromoFocus,
                                            label: isStoreVersion()
                                                ? 'promo_code'.i18n
                                                : 'promo_referral_code'.i18n,
                                            onPressed:
                                                _tvShowReferralCodeDialog,
                                          ),
                                        AppTextButton(
                                          key: const Key('plans.license'),
                                          focusNode: _tvLicenseFocus,
                                          label: 'lantern_pro_license'.i18n,
                                          onPressed: _tvOpenProLicense,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Close, with its glyph on the safe margin's corner.
                Positioned(
                  left: -12,
                  top: -12,
                  child: TvNotInitialFocus(
                    child: IconButton(
                      key: const Key('plans.close'),
                      icon: const Icon(Icons.close),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Focuses [node] after the frame and scrolls it into view, unless the
  /// viewer has already moved focus on this screen (focus still on the
  /// control this screen placed it on does not count) or another route
  /// covers it.
  void _tvInitialFocus(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      // A backgrounded app parks focus on the root scope, which would read
      // as "not moved" below.
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      final focused = FocusManager.instance.primaryFocus;
      final scope = FocusScope.of(context);
      final viewerMoved =
          focused != null &&
          focused != scope &&
          focused.ancestors.contains(scope) &&
          !identical(focused, _tvPlacedFocus);
      if (viewerMoved) return;
      _tvPlacedFocus?.removeListener(_tvPlacedFocusChanged);
      _tvPlacedFocus = node;
      node.addListener(_tvPlacedFocusChanged);
      tvRequestFocus(node);
    });
  }

  /// Whether the cards are showing with at least one plan to pick.
  static bool _tvPlansReady(AsyncValue<PlansData> state) =>
      state is AsyncData<PlansData> && state.value.plans.isNotEmpty;

  /// The control that has focus on its own for [state]: the one branch the
  /// cards render (a reload shows the spinner even with an error or plans
  /// kept from before): the first link while they load, Retry on an error,
  /// the button once they show.
  FocusNode _tvFocusTargetFor(
    AsyncValue<PlansData> state,
    bool isReferralApplied,
  ) {
    if (state.isLoading) {
      return isReferralApplied ? _tvLicenseFocus : _tvPromoFocus;
    }
    return _tvPlansReady(state) ? _tvCtaFocus : _tvRetryFocus;
  }

  /// A checkout shows the app-wide loading overlay, which is not a route:
  /// keys still reach this screen's controls while it is up. They wait: a
  /// second press would start another checkout, the promo dialog's flow
  /// hides the same overlay, the license screen pops Plans around PopScope,
  /// and leaving would strand the overlay. The flow shows it from its first
  /// line and hides it once the checkout settles: a start error, the store's
  /// error, cancel or deferral, or a purchase once its receipt is handled
  /// (acknowledged, or failed, locally or at the backend, which the
  /// acknowledger retries in the background; the account refresh then runs
  /// with the overlay down before moving on, as on a phone: that window is
  /// the shared flow's).
  bool get _tvStoreBusy => context.loaderOverlay.visible;

  /// Back or Close was pressed once during the current store operation.
  bool _tvLeaveWhileBusy = false;

  /// A purchase is done and its account refresh runs with the overlay down.
  bool _tvFinishingPurchase = false;

  void _tvShowReferralCodeDialog() {
    if (_tvStoreBusy) return;
    _tvLeaveWhileBusy = false;
    showReferralCodeDialog();
  }

  void _tvOpenProLicense() {
    if (_tvStoreBusy) return;
    _openProLicense();
  }

  void _tvGetLanternPro() {
    if (_tvStoreBusy || _tvFinishingPurchase) return;
    // Checked again here: the button may have been pressed while a reload
    // replaced the cards.
    if (!_tvPlansReady(ref.read(plansProvider))) return;
    _tvLeaveWhileBusy = false;
    onGetLanternProTap();
  }

  /// Builds without in-app payments activate Pro with a license only.
  Widget _buildLicenseOnlyBody() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: defaultSize),
            child: Center(child: FeatureList()),
          ),
        ),
        SizedBox(height: defaultSize),
        DividerSpace(padding: EdgeInsets.zero),
        Container(
          color: context.bgSurface,
          padding: EdgeInsets.all(defaultSize),
          child: PrimaryButton(
            buttonKey: const Key('plans.license'),
            label: 'lantern_pro_license'.i18n,
            isTaller: true,
            onPressed: _openProLicense,
          ),
        ),
        SizedBox(height: size24),
      ],
    );
  }

  /// Banner shown above the plans list when an affiliate code is applied:
  /// the discount percentage plus a removable chip with the applied code.
  /// Referral (non-affiliate) codes keep the existing per-plan bonus message.
  Widget _buildAffiliateBanner() {
    final response = ref.watch(referralProvider);
    if (!response.isAffiliate) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(left: context.isSmallDevice ? 16 : 0, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: defaultSize),
            child: Text(
              'discount_applied'.i18n.fill(['${response.discountPct}%']),
              style: textTheme.labelMedium!.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              label: Text(response.code),
              labelStyle: textTheme.titleSmall!.copyWith(
                color: context.textAttention,
              ),
              backgroundColor: context.bgAttention,
              deleteIcon: Icon(
                Icons.close,
                size: 18,
                color: context.textAttention,
              ),
              onDeleted: _onRemoveAffiliateCode,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: context.borderAttention),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Clears the affiliate code and refetches the base plans; the notifier
  /// reloads the base SKUs so a later purchase is charged full price.
  void _onRemoveAffiliateCode() {
    // Not under a running checkout (a TV remote still reaches the chip).
    if (context.loaderOverlay.visible) return;
    appLogger.info('Removing applied affiliate code');
    ref.read(referralProvider.notifier).resetReferral();
    ref.read(plansProvider.notifier).fetchPlans();
  }

  void onMenuTap() {
    final isReferralApplied = ref.read(referralProvider).isApplied;
    showAppBottomSheet(
      context: context,
      title: 'payment_options'.i18n,
      scrollControlDisabledMaxHeightRatio: context.isSmallDevice ? 0.5 : 0.4,
      builder: (context, scrollController) {
        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          controller: scrollController,
          children: [
            if (!isReferralApplied) ...{
              AppTile(
                icon: AppImagePaths.star,
                label: isStoreVersion()
                    ? 'promo_code'.i18n
                    : 'promo_referral_code'.i18n,
                onPressed: () {
                  context.pop();
                  showReferralCodeDialog();
                },
              ),
              DividerSpace(),
            },
            AppTile(
              icon: AppImagePaths.keypad,
              label: 'lantern_pro_license'.i18n,
              onPressed: () {
                context.pop();
                _openProLicense();
              },
            ),
          ],
        );
      },
    );
  }

  void _openProLicense() {
    final appSetting = ref.read(appSettingProvider);
    final email = ref.read(userEmailProvider);
    if (appSetting.userLoggedIn && email.isNotEmpty) {
      appRouter.push(LanternProLicense(email: email, code: ''));
      return;
    }
    appRouter.popAndPush(AddEmail(authFlow: AuthFlow.lanternProLicense));
  }

  void showReferralCodeDialog() {
    final referralCodeController = TextEditingController();
    AppDialog.customDialog(
      context: context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 24),
          AppImage(path: AppImagePaths.star, height: 48),
          SizedBox(height: defaultSize),
          Text(
            isStoreVersion() ? 'promo_code'.i18n : 'promo_referral_code'.i18n,
            style: textTheme.headlineSmall!.copyWith(
              color: context.textPrimary,
            ),
          ),
          SizedBox(height: 24),
          AppTextField(
            label: isStoreVersion()
                ? 'promo_code'.i18n
                : 'promo_referral_code'.i18n,
            controller: referralCodeController,
            hintText: 'XXXXXX',
            prefixIcon: AppImagePaths.star,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: onReferralCodeContinue,
          ),
        ],
      ),
      action: [
        AppTextButton(
          label: 'cancel'.i18n,
          underLine: false,
          textColor: context.textDisabled,
          onPressed: () {
            appRouter.pop();
          },
        ),
        AppTextButton(
          label: 'continue'.i18n,
          onPressed: () => onReferralCodeContinue(referralCodeController.text),
        ),
      ],
    );
  }

  /// Applies a deep-linked affiliate code once the plans have loaded;
  /// applying earlier would let the in-flight plans fetch overwrite the
  /// discounted plans returned by the code.
  Future<void> _applyDeepLinkCode(String code) async {
    if (!mounted) return;
    try {
      await ref.read(plansProvider.future);
    } catch (e) {
      appLogger.warning(
        '[Plans] Plans failed to load, skipping deep-linked code: $e',
      );
      return;
    }
    if (!mounted) return;
    await applyReferralCode(code);
  }

  Future<void> onReferralCodeContinue(String code) async {
    if (code.trim().isEmpty) {
      context.showSnackBar('please_enter_referral_code'.i18n);
      return;
    }
    appRouter.pop();
    await applyReferralCode(code);
  }

  Future<void> applyReferralCode(String code) async {
    context.showLoadingDialog();
    final result = await ref
        .read(referralProvider.notifier)
        .applyReferralCodeV2(code);
    if (!mounted) return;

    final failure = result.getLeft().toNullable();
    if (failure != null) {
      appLogger.error('Error applying referral code: $failure');
      context.hideLoadingDialog();
      AppDialog.errorDialog(
        context: context,
        title: 'error'.i18n,
        content: failure.localizedErrorMessage,
      );
      return;
    }

    appLogger.info('Successfully applied referral code');
    context.hideLoadingDialog();
    context.showSnackBar('referral_code_applied'.i18n);
  }

  void onGetLanternProTap() {
    final userSelectedPlan = ref
        .read(plansProvider.notifier)
        .currentSelectedPlan;
    if (userSelectedPlan == null) {
      appLogger.warning(
        'Get Lantern Pro tapped with no plan from the current list',
      );
      return;
    }
    appLogger.info(
      'Get Lantern Pro button tapped with plan: ${userSelectedPlan.id}',
    );

    final appSetting = ref.read(appSettingProvider);
    final isPro = ref.read(isUserProProvider);

    /// Pro user coming to renew — send directly to payment screen by platform
    if (appSetting.userLoggedIn && isPro) {
      appLogger.info('Pro user renewal flow, routing by platform');
      _renewalFlowByPlatform(userSelectedPlan);
      return;
    }

    switch (Platform.operatingSystem) {
      case 'android':
        if (isStoreVersion()) {
          /// user is using play store version
          appLogger.info('Starting in app purchase flow');
          startInAppPurchaseFlow(userSelectedPlan);
          return;
        }
        appLogger.info('Starting sign up flow for android');
        signUpFlow();
        break;
      case 'ios':
        appLogger.info('Starting in app purchase flow IOS');
        startInAppPurchaseFlow(userSelectedPlan);
        break;
      default:
        signUpFlow();
    }
  }

  void _renewalFlowByPlatform(Plan plan) {
    switch (Platform.operatingSystem) {
      case 'ios':
        appLogger.info('Pro renewal: starting in-app purchase flow for iOS');
        startInAppPurchaseFlow(plan);
        break;
      case 'android':
        if (isStoreVersion()) {
          appLogger.info(
            'Pro renewal: starting in-app purchase flow for Android store',
          );
          startInAppPurchaseFlow(plan);
          return;
        }
        appLogger.info('Pro renewal: routing to payment method screen');
        _pushRenewalPaymentScreen();
        break;
      default:
        appLogger.info('Pro renewal: routing to payment method screen');
        _pushRenewalPaymentScreen();
    }
  }

  void _pushRenewalPaymentScreen() {
    final user = ref.read(homeProvider).value;
    final email = user!.legacyUserData.email;
    appRouter.push(
      ChoosePaymentMethod(email: email, authFlow: AuthFlow.renewSubscription),
    );
  }

  Future<void> startInAppPurchaseFlow(Plan plan) async {
    context.showLoadingDialog();
    // Mark a payment as in flight so that ConfirmEmail's back-press guard
    // (confirm_email.dart) preserves the anonymous account if the user
    // backs out before signup completes — same protection Stripe and the
    // external paymentRedirect flow already get.
    ref.read(paymentSessionProvider.notifier).markRedirectInitiated();
    // Forward any applied affiliate/referral code so the purchase is attributed
    // to the affiliate at acknowledgment. Empty when no code is applied.
    final couponCode = ref.read(referralProvider).code;
    final payments = ref.read(paymentProvider.notifier);
    final store = Platform.isIOS ? 'app_store' : 'play_store';
    trackEvent(CheckoutEvent.started, {'provider': store, 'plan': plan.id});
    final result = await payments.startInAppPurchaseFlow(
      planId: plan.id,
      couponCode: couponCode,
      onSuccess: (purchase) {
        trackEvent(CheckoutEvent.storePurchased, {'provider': store});
        processPurchase(purchase, plan);
      },
      onError: (error) {
        trackEvent(CheckoutEvent.failed, {
          'provider': store,
          'reason': 'store_error',
        });
        ref.read(paymentSessionProvider.notifier).clearRedirect();
        if (!mounted) return;
        context.hideLoadingDialog();
        context.showSnackBar(error);
        appLogger.error('Error subscribing to plan: $error');
      },
    );
    if (result.isLeft()) {
      trackEvent(CheckoutEvent.failed, {
        'provider': store,
        'reason': 'start_error',
      });
    }
    if (!mounted) return;
    result.fold((error) {
      ref.read(paymentSessionProvider.notifier).clearRedirect();
      context.hideLoadingDialog();
      context.showSnackBar(error.localizedErrorMessage);
      appLogger.error('Error subscribing to plan: $error', error);
    }, (_) {});
  }

  Future<void> processPurchase(PurchaseDetails purchase, Plan plan) async {
    context.hideLoadingDialog();
    appLogger.info('Subscription successful for plan: ${plan.id}');

    /// Refresh user data from core to update UI immediately after purchase acknowledgment.
    _tvFinishingPurchase = true;
    try {
      await ref.read(homeProvider.notifier).refreshUser();
    } finally {
      _tvFinishingPurchase = false;
    }

    /// IOS Send old purchases to stream
    sl<AppPurchase>().clearCallbacks();

    final appSetting = ref.read(appSettingProvider);
    if (appSetting.userLoggedIn) {
      /// Renewal: user is already logged in, so the back-press protection
      /// the redirect flag was guarding is no longer relevant.
      ref.read(paymentSessionProvider.notifier).clearRedirect();
      userRenewalFlow();
      return;
    }
    signUpFlow();
  }

  void signUpFlow() {
    final appSetting = ref.read(appSettingProvider);
    if (appSetting.userLoggedIn) {
      final user = ref.read(homeProvider).value;
      final email = user!.legacyUserData.email;

      /// User is logged in but not pro — account created but purchase not completed or plan expired
      appRouter.push(
        ChoosePaymentMethod(email: email, authFlow: AuthFlow.renewSubscription),
      );
      return;
    }
    appLogger.debug('Sending user to AddEmail screen for sign up');
    appRouter.push(AddEmail(authFlow: AuthFlow.signUp));
  }

  Future<void> userRenewalFlow() async {
    appLogger.info('Purchase successful, verifying account status with server');
    context.showLoadingDialog();
    appLogger.debug("Checking user account status");
    final isPro = await checkUserAccountStatus(ref, context);
    context.hideLoadingDialog();
    if (isPro) {
      appLogger.debug("User is Pro, showing Lantern Pro dialog");
      AppDialog.showLanternProDialog(
        context: context,
        onPressed: () {
          appRouter.popUntilRoot();
        },
      );
      return;
    } else {
      appLogger.debug(
        "User has made purchase is not reflected in account status, showing Lantern Pro dialog just to avoid blocking flow",
      );
      AppDialog.dialog(
        context: context,
        title: "payment".i18n,
        content: 'it_looks_like_something_went_wrong'.i18n,
        onPressed: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            appRouter.popUntilRoot();
          });
        },
      );
    }
  }

  Future<void> _restorePurchaseFlow() => restorePurchaseFlow();
}
