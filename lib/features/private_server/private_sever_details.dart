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

  const PrivateSeverDetails({
    super.key,
    required this.accounts,
    required this.provider,
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
    final projectList = useState<List<String>>(['Select account']);
    final selectedProject = useState<String?>(null);
    final locationList = useState<List<String>>([]);
    final selectedLocation = useState<String?>(null);
    final serverState = ref.watch(privateServerNotifierProvider);
    final serverNameController = useTextEditingController();

    if (serverState.status == 'EventTypeProjects') {
      projectList.value = serverState.data!.split(', ');
    } else if (serverState.status == 'EventTypeLocations') {
      locationList.value = serverState.data!.split(', ');
    } else if (serverState.status == 'EventTypeProvisioningStarted') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appLogger.info("Private server deployment started successfully.");
        appRouter
            .push(PrivateServerDeploy(serverName: serverNameController.text));
      });
    }

    return BaseScreen(
        title: widget.provider == CloudProvider.digitalOcean
            ? 'do_private_server_setup'.i18n
            : 'gcp_private_server_setup'.i18n,
        extendBody: true,
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: PrimaryButton(
            label: 'start_deployment'.i18n,
            isTaller: true,
            enabled: selectedProject.value != null &&
                serverNameController.text.isNotEmpty,
            onPressed: () => onStartDeployment(
                selectedLocation.value!, serverNameController.text.trim()),
          ),
        ),
        body: ListView(
          children: <Widget>[
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
                    label: 'account'.i18n,
                    prefixIconPath: AppImagePaths.accountSetting,
                    value: selectedAccount.value,
                    items: widget.accounts
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) {
                      selectedAccount.value = value;
                      onUserInput(PrivateServerInput.selectAccount, value);
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
                    label: 'billing_account'.i18n,
                    prefixIconPath: AppImagePaths.creditCard,
                    value: selectedProject.value,
                    items: projectList.value
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) {
                      selectedProject.value = value;
                      onUserInput(PrivateServerInput.selectProject, value);
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
                    "3. ${'choose_your_location'.i18n}",
                    style: textTheme.titleMedium,
                  ),
                  SizedBox(height: 8),
                  DividerSpace(padding: EdgeInsets.zero),
                  SizedBox(height: 8),
                  if (selectedLocation.value != null)
                    AppTile(
                        minHeight: 40,
                        contentPadding: EdgeInsets.zero,
                        icon: Flag(
                            countryCode: selectedLocation.value!.countryCode),
                        label: selectedLocation.value!.locationName,
                        onPressed: () {
                          appRouter.push(PrivateServerLocation(
                            location: locationList.value,
                            selectedLocation: selectedLocation.value,
                            provider: widget.provider,
                            onLocationSelected: (p0) {
                              selectedLocation.value = p0;
                            },
                          ));
                        },
                        trailing: AppTextButton(
                          onPressed: () {
                            appRouter.push(PrivateServerLocation(
                              location: locationList.value,
                              selectedLocation: selectedLocation.value,
                              provider: widget.provider,
                              onLocationSelected: (p0) {
                                selectedLocation.value = p0;
                              },
                            ));
                          },
                          label: 'change'.i18n,
                        ))
                  else
                    Center(
                        child: AppTextButton(
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
                    "4. ${'name_your_server'.i18n}",
                    style: textTheme.titleMedium,
                  ),
                  SizedBox(height: 8),
                  DividerSpace(padding: EdgeInsets.zero),
                  SizedBox(height: 8),
                  AppTextField(
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

  Future<void> onUserInput(PrivateServerInput input, String account) async {
    context.showLoadingDialog();
    appLogger.info("Selected account: $account");
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
