import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';

@RoutePage(name: 'PrivateServerDetails')
class PrivateSeverDetails extends StatefulHookConsumerWidget {
  final List<String> accounts;

  const PrivateSeverDetails({
    super.key,
    required this.accounts,
  });

  @override
  ConsumerState<PrivateSeverDetails> createState() =>
      _PrivateSeverDetailsState();
}

class _PrivateSeverDetailsState extends ConsumerState<PrivateSeverDetails> {
  @override
  Widget build(BuildContext context) {
    return BaseScreen(
        title: 'do_private_server_setup'.i18n, body: _buildBody(context, ref));
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final selectedAccount = useState<String?>(null);
    final projectList = useState<List<String>>([]);
    final selectedProject = useState<String?>(null);
    final locationList = useState<List<String>>([]);
    final selectedLocation = useState<String?>(null);
    final serverState = ref.watch(privateServerNotifierProvider);
    final serverNameController = useTextEditingController();

    if (serverState.status == 'EventTypeProjects') {
      projectList.value = serverState.data!.split(',');
    } else if (serverState.status == 'EventTypeLocations') {
      locationList.value = serverState.data!.split(',');
    } else if (serverState.status == 'EventTypeProvisioningStarted') {
      appRouter
          .push(PrivateServerDeploy(serverName: serverNameController.text));
    }
    return Column(
      children: <Widget>[
        SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "1. Choose your account",
                style: textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              DividerSpace(padding: EdgeInsets.zero),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.gray3,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButton<String>(
                  isExpanded: true,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  style: textTheme.bodyMedium!.copyWith(
                    color: AppColors.gray9,
                  ),
                  value: selectedAccount.value,
                  borderRadius: BorderRadius.circular(16),
                  underline: const SizedBox.shrink(),
                  items: widget.accounts
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e),
                          ))
                      .toList(),
                  onChanged: (value) {
                    selectedAccount.value = value;
                    onUserInput(PrivateServerInput.selectAccount, value!);
                  },
                ),
              )
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
                "2. Choose your project",
                style: textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              DividerSpace(padding: EdgeInsets.zero),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.gray3,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButton<String>(
                  isExpanded: true,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  style: textTheme.bodyMedium!.copyWith(
                    color: AppColors.gray9,
                  ),
                  value: selectedProject.value,
                  borderRadius: BorderRadius.circular(16),
                  underline: const SizedBox.shrink(),
                  items: projectList.value
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e),
                          ))
                      .toList(),
                  onChanged: (value) {
                    selectedProject.value = value;
                    onUserInput(PrivateServerInput.selectProject, value!);
                  },
                ),
              )
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
              SizedBox(height: 16),
              if (selectedLocation.value != null)
                AppTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    icon:
                        Flag(countryCode: selectedLocation.value!.countryCode),
                    label: selectedLocation.value!.locationName,
                    onPressed: () {
                      appRouter.push(PrivateServerLocation(
                        location: locationList.value,
                        selectedLocation: selectedLocation.value,
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
                          appRouter.push(PrivateServerLocation(
                            location: locationList.value,
                            selectedLocation: selectedLocation.value,
                            onLocationSelected: (p0) {
                              selectedLocation.value = p0;
                            },
                          ));
                        })),
              SizedBox(height: 8),
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
                "4. Name your server",
                style: textTheme.titleMedium,
              ),
              SizedBox(height: 16),
              AppTextField(
                hintText: "server_name".i18n,
                controller: serverNameController,
                prefixIcon: AppImage(path: AppImagePaths.server),
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
        Spacer(),
        PrimaryButton(
          label: 'start_deployment'.i18n,
          enabled: selectedProject.value != null &&
              serverNameController.text.isNotEmpty,
          onPressed: () => onStartDeployment(
              selectedLocation.value!, serverNameController.text.trim()),
        ),
      ],
    );
  }

  Future<void> onUserInput(PrivateServerInput input, String account) async {
    context.showLoadingDialog();
    appLogger.info("Selected account: $account");
    final result = await ref
        .read(privateServerNotifierProvider.notifier)
        .setUserInput(input, account.trim());
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
    appLogger.info("Starting deployment for location: $location");
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
