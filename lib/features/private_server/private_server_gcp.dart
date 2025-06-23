import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/billing_account.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/widgets/card_dropdown.dart';
import 'package:lantern/core/widgets/labeled_card_dropdown.dart';
import 'package:lantern/core/widgets/labeled_card_input.dart';

final _formKey = GlobalKey<FormState>();

@RoutePage(name: 'PrivateServerGCP')
class PrivateServerGCP extends HookConsumerWidget {
  const PrivateServerGCP({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSelectedCode = useState('AU');

    final projectNameController = useTextEditingController();
    final serverNameController = useTextEditingController();
    final billingAccounts = useState<List<BillingAccount>>([
      // Test data. Substitute with real Google accounts after enabling sign-in
      BillingAccount(
        id: '343633',
        text: 'Derek\'s Account',
        provider: CloudProvider.googleCloud,
      ),
      BillingAccount(
        id: '343638',
        text: 'Acme Billing',
        provider: CloudProvider.googleCloud,
      ),
    ]);
    final billingAccount = useState<BillingAccount?>(null);
    final currentSelectedLocation = useState<ServerLocation?>(null);

    void startDeployment() {
      if (_formKey.currentState!.validate() &&
          billingAccount.value != null &&
          currentSelectedLocation.value != null) {
        // Trigger deployment
        appRouter.push(DeployingServer());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('all_required_fields'.i18n)),
        );
      }
    }

    return BaseScreen(
      title: 'setup_private_server'.i18n,
      padded: true,
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Name project:
              LabeledCardInput(
                header: 'name_your_google_cloud_project'.i18n,
                label: 'google_project'.i18n,
                input: AppTextField(
                  prefixIcon: AppImagePaths.accountCircle,
                  controller: projectNameController,
                  validator: (value) => value == null || value.isEmpty
                      ? 'field_name_required'.i18n
                      : null,
                  hintText: '',
                ),
              ),
              LabeledCardInput(
                header: 'choose_google_account'.i18n,
                label: 'billing_account'.i18n,
                input: CardDropdown(
                  prefixIcon: AppImagePaths.creditCard,
                  value: billingAccount.value?.text,
                  items: billingAccounts.value
                      .map((ba) => DropdownMenuItem(
                          value: ba.text, child: Text(ba.text)))
                      .toList(),
                  onChanged: (val) => billingAccount.value =
                      billingAccounts.value.firstWhere((ba) => ba.text == val),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'field_required'.i18n : null,
                  hintText: 'billing_account_hint'.i18n,
                ),
              ),
              LabeledCardDropdownWithFlag(
                titleKey: 'server_location'.i18n,
                countryCode: currentSelectedCode.value,
                countryLabelKey: currentSelectedLocation.value?.label ?? '',
                onChoose: () => appRouter.push(ServerLocations(
                  title: 'gcp_private_server_location'.i18n,
                  provider: CloudProvider.googleCloud,
                  selectedCode: currentSelectedCode.value,
                  onSelected: (value) {
                    currentSelectedCode.value = value.code;
                    currentSelectedLocation.value = value;
                  },
                )),
              ),
              LabeledCardInput(
                header: 'name_your_server'.i18n,
                label: 'server_name'.i18n,
                controller: serverNameController,
                prefixIcon: AppImagePaths.server,
                hint:
                    'How the server will appear in the server selection list.',
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'start_deployment'.i18n,
                onPressed: () => startDeployment(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
