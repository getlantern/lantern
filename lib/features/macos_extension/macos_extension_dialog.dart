import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:window_manager/window_manager.dart';

/// Asks the user to install or enable the network extension, from wherever
/// the VPN needs it. Onboarding shows the same content as its last page.
@RoutePage(name: 'MacOSExtensionDialog')
class MacOSExtensionDialog extends ConsumerWidget {
  const MacOSExtensionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(macosExtensionProvider);
    return BaseScreen(
      key: const Key('macos_extension.screen'),
      title: '',
      appBar: CustomAppBar(
        leading: SizedBox(),
        title: LanternLogo(color: context.textPrimary),
        actions: [CloseButton()],
        backgroundColor: context.bgElevated,
      ),
      body: MacOSExtensionWatcher(
        onReady: () => appRouter.pop(true),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            MacOSExtensionContent(state: state),
            const SizedBox(height: 48.0),
            PrimaryButton(
              buttonKey: const Key('macos_extension.install'),
              label: macOSExtensionButtonLabel(state.status),
              isTaller: true,
              onPressed: () => installMacOSExtension(ref, context, state),
            ),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
    );
  }
}

/// The explainer itself: the illustration, the heading, the message for the
/// extension's [state], and the hint to click Open System Settings.
class MacOSExtensionContent extends StatelessWidget {
  const MacOSExtensionContent({super.key, required this.state});

  final MacOSExtensionState state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final requiresEnable = state.status == SystemExtensionStatus.requiresEnable;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        KeyedSubtree(
          key: Key('macos_extension.status.${state.status.name}'),
          child: const SizedBox.shrink(),
        ),
        AppImage(path: AppImagePaths.sysDialog, useThemeColor: false),
        const SizedBox(height: 48.0),
        Text(
          'enable_network_extension'.i18n,
          style: textTheme.headlineSmall!.copyWith(color: context.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            requiresEnable
                ? 'network_extension_disabled_message'.i18n
                : 'enable_network_extension_message'.i18n,
            style: textTheme.bodyLarge!.copyWith(color: context.textSecondary),
          ),
        ),
        if (!requiresEnable) ...[
          const SizedBox(height: 16.0),
          RichText(
            text: TextSpan(
              style: textTheme.bodyLarge!.copyWith(color: context.textTertiary),
              children: [
                TextSpan(text: 'click'.i18n),
                WidgetSpan(child: SizedBox(width: 4.0)),
                TextSpan(
                  text: 'open_system_settings'.i18n,
                  style: AppTextStyles.bodyLargeBold.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                WidgetSpan(child: SizedBox(width: 4.0)),
                TextSpan(text: 'when_prompted'.i18n),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Keeps the extension's status current while [child] shows it: re-queries
/// it when the window regains focus (re-enabling the extension in System
/// Settings leaves no pending request to call back), reports an error, and
/// calls [onReady] once the extension is installed and active.
class MacOSExtensionWatcher extends StatefulHookConsumerWidget {
  const MacOSExtensionWatcher({
    super.key,
    required this.onReady,
    required this.child,
  });

  final VoidCallback onReady;
  final Widget child;

  @override
  ConsumerState<MacOSExtensionWatcher> createState() =>
      _MacOSExtensionWatcherState();
}

class _MacOSExtensionWatcherState extends ConsumerState<MacOSExtensionWatcher>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowFocus() {
    ref.read(macosExtensionProvider.notifier).isSystemExtensionInstalled();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(macosExtensionProvider);
    appLogger.info("Current System Extension Status: ${state.status}");
    useEffect(() {
      if (state.status == SystemExtensionStatus.error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          appLogger.error(
            "Error fetching System Extension Status: ${state.message}",
          );
          AppDialog.errorDialog(
            context: context,
            title: 'error'.i18n,
            content: state.message ?? 'unknown_error_occurred'.i18n,
          );
        });
      }
      if (state.isReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          appLogger.info("System Extension is installed and activated.");
          widget.onReady();
        });
      }
      return null;
    }, [state.status]);
    return widget.child;
  }
}

/// The primary button's label for the extension's [status].
String macOSExtensionButtonLabel(SystemExtensionStatus status) {
  switch (status) {
    case SystemExtensionStatus.requiresApproval:
      return 'activate_extension'.i18n;
    case SystemExtensionStatus.requiresEnable:
      return 'open_system_settings'.i18n;
    default:
      return 'install_now'.i18n;
  }
}

/// What the primary button does for the extension's [state]: opens System
/// Settings to approve or enable it, asks for a restart, or installs it.
Future<void> installMacOSExtension(
  WidgetRef ref,
  BuildContext context,
  MacOSExtensionState state,
) async {
  appLogger.info("Current System Extension Status: $state");
  if (state.status == SystemExtensionStatus.requiresApproval ||
      state.status == SystemExtensionStatus.requiresEnable) {
    ref.read(macosExtensionProvider.notifier).openSystemExtension();
    appLogger.info("Opening System Settings for ${state.status.name}");
    return;
  }

  if (state.status == SystemExtensionStatus.requiresReboot) {
    context.showSnackBar(
      state.message ??
          'Restart macOS to finish updating the network extension.',
    );
    return;
  }

  appLogger.info("Triggering System Extension Installation");
  final result = await ref
      .read(macosExtensionProvider.notifier)
      .triggerSystemExtensionInstallation();

  result.fold(
    (failure) {
      appLogger.error("Failure: ${failure.error}");
      if (!context.mounted) return;
      AppDialog.errorDialog(
        context: context,
        title: 'error'.i18n,
        content: failure.localizedErrorMessage,
      );
    },
    (result) {
      appLogger.info("System Extension Installation Triggered: $result");
    },
  );
}
