import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_dropdown.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';

@RoutePage(name: 'PrivateServerDetails')
class PrivateSeverDetails extends StatefulHookConsumerWidget {
  final List<String> accounts;
  final CloudProvider provider;

  /// if true, it means some values are pre filled
  /// and user only need to setup location and server name
  final bool isPreFilled;

  const PrivateSeverDetails({
    super.key,
    required this.accounts,
    required this.provider,
    this.isPreFilled = false,
  });

  @override
  ConsumerState<PrivateSeverDetails> createState() =>
      _PrivateSeverDetailsState();
}

class _PrivateSeverDetailsState extends ConsumerState<PrivateSeverDetails> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final selectedAccount = useState<String?>(null);
    final projectList = useState<List<String>>([]);
    final selectedProject = useState<String?>(null);
    final locationList = useState<List<String>>([]);
    final selectedLocation = useState<String?>(null);
    final serverState = ref.watch(privateServerNotifierProvider);
    final serverNameController = useTextEditingController();
    final navigatedToDeploy = useRef(false);

    useEffect(() {
      if (serverState.status == 'EventTypeProjects' &&
          (serverState.data?.isNotEmpty ?? false)) {
        projectList.value = serverState.data!
            .split(', ')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      if (serverState.status == 'EventTypeLocations' &&
          (serverState.data?.isNotEmpty ?? false)) {
        locationList.value = serverState.data!
            .split(', ')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      if (serverState.status == 'EventTypeProvisioningStarted' &&
          !navigatedToDeploy.value) {
        navigatedToDeploy.value = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appLogger.info("Private server deployment started successfully.");
          appRouter.push(
            PrivateServerDeploy(serverName: serverNameController.text),
          );
        });
      }

      return null;
    }, [serverState.status, serverState.data]);

    return BaseScreen(
        title: widget.provider == CloudProvider.digitalOcean
            ? 'do_private_server_setup'.i18n
            : 'gcp_private_server_setup'.i18n,
        extendBody: true,
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: PrimaryButton(
            key: const Key('psd.startDeployment'),
            label: 'start_deployment'.i18n,
            isTaller: true,
            enabled: isStartDeploymentEnabled(selectedProject.value,
                selectedLocation.value, serverNameController.text.trim()),
            onPressed: () => onStartDeployment(
              selectedLocation.value!,
              serverNameController.text.trim(),
            ),
          ),
        ),
        body: ListView(
          children: <Widget>[
            /// If isPreFilled is false, there are no default values provided.
            /// This means the user needs to set up account, project, location, and server name.
            /// If isPreFilled is true, only server location and name need to be set up.
            if (!widget.isPreFilled) ...{
              AppCard(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "1. ${'choose_your_account'.i18n}",
                      style: textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    DividerSpace(padding: EdgeInsets.zero),
                    SizedBox(height: 8),
                    AppDropdown(
                      key: const Key('psd.accountDropdown'),
                      label: 'account'.i18n,
                      prefixIconPath: AppImagePaths.accountSetting,
                      value: selectedAccount.value,
                      items: widget.accounts
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) {
                        selectedAccount.value = value;
                        // reset dependents
                        selectedProject.value = null;
                        projectList.value = <String>[];
                        selectedLocation.value = null;
                        locationList.value = <String>[];

                        if (value.isNotEmpty) {
                          onUserInput(PrivateServerInput.selectAccount, value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "2. ${'choose_your_project'.i18n}",
                      style: textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    DividerSpace(padding: EdgeInsets.zero),
                    SizedBox(height: 8),
                    AppDropdown(
                      key: const Key('psd.projectDropdown'),
                      label: 'billing_account'.i18n,
                      prefixIconPath: AppImagePaths.creditCard,
                      value: selectedProject.value,
                      items: projectList.value
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) {
                        selectedProject.value = value;
                        selectedLocation.value = null;
                        locationList.value = <String>[];

                        if (value.isNotEmpty) {
                          onUserInput(PrivateServerInput.selectProject, value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            },
            SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${widget.isPreFilled ? '1' : '3'}. ${'choose_your_location'.i18n}",
                    style: textTheme.titleMedium,
                  ),
                  SizedBox(height: 8),
                  DividerSpace(padding: EdgeInsets.zero),
                  SizedBox(height: 8),
                  if (selectedLocation.value != null)
                    AppTile(
                        key: const Key('psd.locationTile'),
                        minHeight: 40,
                        contentPadding: EdgeInsets.zero,
                        icon: Flag(
                          countryCode: selectedLocation.value!.countryCode,
                        ),
                        label: selectedLocation.value!.locationName,
                        onPressed: () => _openLocationPicker(
                              current: selectedLocation.value,
                              locations: locationList.value,
                              onPicked: (p0) => selectedLocation.value = p0,
                            ),
                        trailing: AppTextButton(
                          onPressed: () => _openLocationPicker(
                            current: selectedLocation.value,
                            locations: locationList.value,
                            onPicked: (p0) => selectedLocation.value = p0,
                          ),
                          label: 'change'.i18n,
                        ))
                  else
                    Center(
                        child: AppTextButton(
                            key: const Key('psd.chooseLocation'),
                            label: 'choose_location'.i18n,
                            onPressed: () {
                              appRouter.push(
                                PrivateServerLocation(
                                  location: locationList.value,
                                  provider: widget.provider,
                                  selectedLocation: selectedLocation.value,
                                  onLocationSelected: (p0) {
                                    selectedLocation.value = p0;
                                  },
                                ),
                              );
                            })),
                ],
              ),
            ),
            SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${widget.isPreFilled ? '2' : '4'}. ${'name_your_server'.i18n}",
                    style: textTheme.titleMedium,
                  ),
                  SizedBox(height: 8),
                  DividerSpace(padding: EdgeInsets.zero),
                  SizedBox(height: 8),
                  AppTextField(
                    key: const Key('psd.serverName'),
                    hintText: "server_name".i18n,
                    label: "server_name".i18n,
                    controller: serverNameController,
                    prefixIcon: AppImage(path: AppImagePaths.server),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  SizedBox(height: 4),
                  Center(
                    child: Text(
                      "how_server_appears".i18n,
                      style: textTheme.labelMedium!.copyWith(
                        color: AppColors.gray6,
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                ],
              ),
            ),
            SizedBox(height: 36),
          ],
        ));
  }

  bool isStartDeploymentEnabled(
      String? project, String? location, String serverName) {
    if (widget.isPreFilled) {
      return location != null && serverName.isNotEmpty;
    }
    return (project != null &&
        (location != null && location.isNotEmpty) &&
        serverName.isNotEmpty);
  }

  Future<void> onUserInput(PrivateServerInput input, String account) async {
    context.showLoadingDialog();
    appLogger.info("Setting user input: $input with value: $account");
    final result = await ref
        .read(privateServerNotifierProvider.notifier)
        .setUserInput(input, account);
    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) {
        context.hideLoadingDialog();
        appLogger.info("${input.name} set successfully: $account");
      },
    );
  }

  void _openLocationPicker({
    required String? current,
    required List<String> locations,
    required ValueChanged<String> onPicked,
  }) {
    appRouter.push(
      PrivateServerLocation(
        location: locations,
        selectedLocation: current,
        provider: widget.provider,
        onLocationSelected: onPicked,
      ),
    );
  }

  Future<void> onStartDeployment(String location, String serverName) async {
    appLogger.info(
        "Starting deployment for location: $location with name: $serverName");
    context.showLoadingDialog();
    final result = await ref
        .read(privateServerNotifierProvider.notifier)
        .startDeployment(location, serverName);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) {
        context.hideLoadingDialog();
        appLogger
            .info("Private server deployment started for location: $location");
      },
    );
  }
}
