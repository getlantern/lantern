import 'package:auto_route/auto_route.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/widgets/oauth_login.dart';
import 'package:lantern/core/keys/app_keys.dart';
import 'package:lantern/features/auth/provider/auth_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:loader_overlay/loader_overlay.dart';

import 'package:lantern/features/home/provider/home_notifier.dart';

@RoutePage(name: 'AddEmail')
class AddEmail extends ConsumerStatefulWidget {
  final AuthFlow authFlow;

  ///password will be used for change email flow
  /// all other times it will be null
  final String? password;

  const AddEmail({super.key, this.authFlow = AuthFlow.signUp, this.password});

  @override
  ConsumerState<AddEmail> createState() => _AddEmailState();
}

class _AddEmailState extends ConsumerState<AddEmail> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _accountRefreshInProgress = true;
  Failure? _accountRefreshFailure;
  VoidCallback? _hideActiveLoadingOverlay;
  TextTheme? textTheme;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController()..addListener(_onEmailChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOnEntry());
  }

  @override
  void dispose() {
    _hideLoadingDialog();
    _emailController
      ..removeListener(_onEmailChanged)
      ..dispose();
    super.dispose();
  }

  void _showLoadingDialog() {
    final overlay = context.loaderOverlay;
    overlay.show();
    _hideActiveLoadingOverlay = overlay.hide;
  }

  void _hideLoadingDialog() {
    final hide = _hideActiveLoadingOverlay;
    _hideActiveLoadingOverlay = null;
    hide?.call();
  }

  void _onEmailChanged() {
    if (mounted) setState(() {});
  }

  void _setEmail(String email) {
    if (_emailController.text == email) return;
    _emailController.value = TextEditingValue(
      text: email,
      selection: TextSelection.collapsed(offset: email.length),
    );
  }

  Future<void> _refreshOnEntry() async {
    if (!mounted) return;
    setState(() {
      _accountRefreshInProgress = true;
      _accountRefreshFailure = null;
    });

    // Do not race the provider's asynchronous cached-data build: a late build
    // completion would otherwise overwrite the authoritative server result.
    try {
      await ref.read(homeProvider.future);
    } catch (e) {
      appLogger.warning(
        'Cached account state was unavailable before server refresh: $e',
      );
    }
    if (!mounted) return;
    final cachedWasRegistered =
        ref.read(homeProvider).value?.legacyUserData.unpassRegistered ?? false;

    final result = await ref.read(homeProvider.notifier).fetchUserData();
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _accountRefreshInProgress = false;
          _accountRefreshFailure = failure;
        });
      },
      (user) {
        final userData = user.legacyUserData;
        if (widget.authFlow != AuthFlow.changeEmail) {
          if (userData.unpassRegistered && userData.email.isNotEmpty) {
            _setEmail(userData.email);
          } else if (cachedWasRegistered) {
            _emailController.clear();
          }
        }
        setState(() {
          _accountRefreshInProgress = false;
          _accountRefreshFailure = null;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(homeProvider).value;
    final isUserRegistered = user?.legacyUserData.unpassRegistered ?? false;
    final currentEmail = user?.legacyUserData.email ?? '';
    final isChangeEmailFlow = widget.authFlow == AuthFlow.changeEmail;

    if (isUserRegistered &&
        !isChangeEmailFlow &&
        currentEmail.isNotEmpty &&
        _emailController.text != currentEmail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setEmail(currentEmail);
      });
    }

    textTheme = Theme.of(context).textTheme;
    final accountStateReady =
        !_accountRefreshInProgress && _accountRefreshFailure == null;
    return EnterKeyShortcut(
      onEnter: () {
        if (accountStateReady &&
            _canSubmitEmail(_emailController.text, currentEmail)) {
          onContinuePressed(SignUpMethodType.email, currentEmail);
        }
      },
      child: BaseScreen(
        title: isChangeEmailFlow
            ? 'enter_new_email'.i18n
            : 'add_your_email'.i18n,
        body: Column(
          children: [
            if (_accountRefreshInProgress)
              const LinearProgressIndicator()
            else if (_accountRefreshFailure case final failure?)
              Padding(
                padding: EdgeInsets.only(bottom: defaultSize),
                child: Column(
                  children: [
                    Text(
                      failure.localizedErrorMessage,
                      style: textTheme!.bodyMedium!.copyWith(
                        color: context.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppTextButton(
                      key: AuthKeys.signUpAccountRefreshRetryButton,
                      label: 'retry'.i18n,
                      onPressed: _refreshOnEntry,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: IgnorePointer(
                ignoring: !accountStateReady,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          fieldKey: AuthKeys.signUpEmailField,
                          enable: !isUserRegistered || isChangeEmailFlow,
                          controller: _emailController,
                          label: 'email'.i18n,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [
                            AutofillHints.email,
                            AutofillHints.username,
                          ],
                          prefixIcon: AppImagePaths.email,
                          hintText: 'example@gmail.com',
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) {
                              return null;
                            }
                            if (!email.isValidEmail()) {
                              return 'invalid_email'.i18n;
                            }
                            if (isChangeEmailFlow &&
                                _isSameEmail(email, currentEmail)) {
                              return 'email_must_be_different'.i18n;
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 4),
                        if (isUserRegistered &&
                            widget.authFlow == AuthFlow.lanternProLicense) ...{
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: defaultSize,
                            ),
                            child: Text(
                              'lantern_pro_license_applied'.i18n,
                              style: textTheme!.bodyMedium!.copyWith(
                                color: context.textDisabled,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          SizedBox(height: defaultSize),
                        },
                        if (widget.authFlow == AuthFlow.changeEmail)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: defaultSize,
                            ),
                            child: Text(
                              'change_email_message'.i18n,
                              style: textTheme!.bodyMedium!.copyWith(
                                color: context.textDisabled,
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: defaultSize,
                            ),
                            child: Text(
                              'add_your_email_message'.i18n,
                              style: textTheme!.bodyMedium!.copyWith(
                                color: context.textDisabled,
                              ),
                            ),
                          ),
                        SizedBox(height: 32),
                        PrimaryButton(
                          key: AuthKeys.signUpContinueButton,
                          label: 'continue'.i18n,
                          enabled:
                              accountStateReady &&
                              _canSubmitEmail(
                                _emailController.text,
                                currentEmail,
                              ),
                          isTaller: true,
                          onPressed: () => onContinuePressed(
                            SignUpMethodType.email,
                            currentEmail,
                          ),
                        ),
                        if (isUserRegistered && !isChangeEmailFlow) ...[
                          SizedBox(height: defaultSize),
                          Center(
                            child: AppTextButton(
                              key: AuthKeys.signUpUseDifferentAccountButton,
                              label: 'use_a_different_account'.i18n,
                              onPressed: _useDifferentAccount,
                            ),
                          ),
                        ],
                        if (!isUserRegistered) ...{
                          SizedBox(height: defaultSize),
                          DividerSpace(),
                          SizedBox(height: defaultSize),
                          OAuthLogin(
                            methodType: SignUpMethodType.google,
                            onResult: (token) =>
                                onOAuthResult(token, SignUpMethodType.google),
                          ),
                          SizedBox(height: defaultSize),
                          OAuthLogin(
                            methodType: SignUpMethodType.apple,
                            foregroundColor: context.textPrimary,
                            onResult: (token) =>
                                onOAuthResult(token, SignUpMethodType.apple),
                          ),
                          SizedBox(height: defaultSize),
                          DividerSpace(),
                          SizedBox(height: defaultSize),
                          if (isStoreVersion() &&
                              widget.authFlow == AuthFlow.signUp)
                            Center(
                              child: AppTextButton(
                                key: AuthKeys.signUpContinueWithoutEmailButton,
                                label: 'continue_without_email'.i18n,
                                textColor: AppColors.gray9,
                                onPressed: () => navigateRoute(
                                  SignUpMethodType.withoutEmail,
                                  "",
                                ),
                              ),
                            ),
                        },
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isProblematicEmail(String email) {
    const problematicDomains = ['@sina.com', '@qq.com', '@163.com', '@126.com'];

    return problematicDomains.any(email.endsWith);
  }

  bool _canSubmitEmail(String email, String currentEmail) {
    final trimmedEmail = email.trim();
    if (!trimmedEmail.isValidEmail()) {
      return false;
    }
    if (widget.authFlow == AuthFlow.changeEmail &&
        _isSameEmail(trimmedEmail, currentEmail)) {
      return false;
    }
    return true;
  }

  bool _isSameEmail(String email, String currentEmail) {
    return currentEmail.trim().isNotEmpty &&
        email.trim().toLowerCase() == currentEmail.trim().toLowerCase();
  }

  void onContinuePressed(SignUpMethodType type, String currentEmail) {
    final email = _emailController.text.trim();
    if (!_canSubmitEmail(email, currentEmail)) {
      _formKey.currentState!.validate();
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final cachedUserIsRegistered =
        ref.read(homeProvider).value?.legacyUserData.unpassRegistered ?? false;
    if (_isProblematicEmail(email) && !cachedUserIsRegistered) {
      _showEmailDeliverabilityNotice(() => _handleContinue(type, email));
      return;
    }
    _handleContinue(type, email);
  }

  Future<void> _handleContinue(SignUpMethodType type, String email) async {
    try {
      if (!_formKey.currentState!.validate()) {
        return;
      }
      _showLoadingDialog();
      final refreshResult = await _refreshAccountState();
      if (!mounted) return;

      UserResponseModel? authoritativeUser;
      refreshResult.fold((_) {}, (user) => authoritativeUser = user);
      if (authoritativeUser == null) {
        _hideLoadingDialog();
        return;
      }
      final userData = authoritativeUser!.legacyUserData;
      _hideLoadingDialog();

      if (widget.authFlow == AuthFlow.changeEmail) {
        appLogger.debug('Starting change email flow');
        await startChangeEmailFlow(email);
        return;
      }

      if (userData.unpassRegistered) {
        final backendEmail = userData.email.trim();
        if (backendEmail.isEmpty) {
          _showInvalidRegisteredAccount();
          return;
        }
        _setEmail(backendEmail);
        appLogger.info(
          'Server reports an existing registered account; starting password recovery',
        );
        await startForgotPasswordFlow(backendEmail);
        return;
      }

      appLogger.debug('Starting signup flow');
      await signupFlow(email);
    } catch (e) {
      _hideLoadingDialog();
      appLogger.error('Error in _handleContinue: $e');
      if (mounted) context.showSnackBar('an_error_occurred'.i18n);
    }
  }

  Future<Either<Failure, UserResponseModel>> _refreshAccountState() async {
    final result = await ref.read(homeProvider.notifier).fetchUserData();
    if (!mounted) return result;

    result.fold(
      (failure) {
        setState(() => _accountRefreshFailure = failure);
        appLogger.error(
          'Authoritative account refresh failed: ${failure.error}',
        );
      },
      (_) {
        if (_accountRefreshFailure != null) {
          setState(() => _accountRefreshFailure = null);
        }
      },
    );
    return result;
  }

  Future<void> signupFlow(String email) async {
    _showLoadingDialog();
    final tempPassword = generatePassword();
    final result = await ref
        .read(authProvider.notifier)
        .signUpWithEmail(email, tempPassword);
    if (!mounted) return;

    Failure? signupFailure;
    result.fold((failure) => signupFailure = failure, (_) {});
    if (signupFailure == null) {
      _hideLoadingDialog();
      await startForgotPasswordFlow(email, tempPassword);
      return;
    }

    final failure = signupFailure!;
    if (_isSignupConflict(failure)) {
      final refreshResult = await _refreshAccountState();
      if (!mounted) return;

      UserResponseModel? authoritativeUser;
      refreshResult.fold((_) {}, (user) => authoritativeUser = user);
      if (authoritativeUser == null) {
        _hideLoadingDialog();
        return;
      }

      final userData = authoritativeUser!.legacyUserData;
      if (userData.unpassRegistered && userData.email.trim().isNotEmpty) {
        final backendEmail = userData.email.trim();
        _setEmail(backendEmail);
        _hideLoadingDialog();
        appLogger.info(
          'Signup conflicted after account registration; rerouting to password recovery',
        );
        await startForgotPasswordFlow(backendEmail);
        return;
      }

      _hideLoadingDialog();
      _showSignupConflictDialog(failure);
      return;
    }

    _hideLoadingDialog();
    AppDialog.errorDialog(
      context: context,
      title: 'error'.i18n,
      content: failure.localizedErrorMessage,
    );
  }

  bool _isSignupConflict(Failure failure) {
    final details = '${failure.error} ${failure.localizedErrorMessage}'
        .toLowerCase();
    return failure.localizedErrorMessage == 'signup_error_user_exists'.i18n ||
        details.contains('signup_user_exists') ||
        details.contains('user already exists') ||
        details.contains('legacy user id already exists');
  }

  void _showSignupConflictDialog(Failure failure) {
    AppDialog.customDialog(
      context: context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 24),
          Text('create_account_error'.i18n, style: textTheme!.headlineMedium),
          SizedBox(height: defaultSize),
          Text(failure.localizedErrorMessage, style: textTheme!.bodyMedium),
        ],
      ),
      action: [
        AppTextButton(
          label: 'sign_in'.i18n,
          onPressed: () {
            appRouter.maybePop();
            appRouter.push(SignInEmail());
          },
        ),
        AppTextButton(
          label: 'ok'.i18n,
          textColor: AppColors.gray6,
          onPressed: () {
            appRouter.maybePop();
          },
        ),
      ],
    );
  }

  Future<void> _useDifferentAccount() async {
    _showLoadingDialog();
    final refreshResult = await _refreshAccountState();
    if (!mounted) return;

    UserResponseModel? authoritativeUser;
    refreshResult.fold((_) {}, (user) => authoritativeUser = user);
    if (authoritativeUser == null) {
      _hideLoadingDialog();
      return;
    }

    final userData = authoritativeUser!.legacyUserData;
    if (!userData.unpassRegistered) {
      _hideLoadingDialog();
      _emailController.clear();
      return;
    }
    final backendEmail = userData.email.trim();
    if (backendEmail.isEmpty) {
      _hideLoadingDialog();
      _showInvalidRegisteredAccount();
      return;
    }

    final result = await ref.read(lanternServiceProvider).logout(backendEmail);
    if (!mounted) return;
    result.fold(
      (failure) {
        _hideLoadingDialog();
        appLogger.error('Different-account rollover failed: ${failure.error}');
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (newUser) {
        ref.read(homeProvider.notifier).clearLogoutData();
        ref.read(homeProvider.notifier).updateUserData(newUser);
        _emailController.clear();
        _hideLoadingDialog();
        appLogger.info('Switched to a fresh anonymous account');
      },
    );
  }

  void _showInvalidRegisteredAccount() {
    appLogger.error(
      'Server returned unpassRegistered=true without a usable email',
    );
    context.showSnackBar('an_error_occurred'.i18n);
  }

  Future<void> startForgotPasswordFlow(
    String email, [
    String? tempPassword,
  ]) async {
    _showLoadingDialog();
    final result = await ref
        .read(authProvider.notifier)
        .startRecoveryByEmail(email);
    result.fold(
      (failure) {
        _hideLoadingDialog();
        context.showSnackBar(failure.localizedErrorMessage);
      },
      (_) {
        _hideLoadingDialog();
        navigateRoute(SignUpMethodType.email, email, tempPassword);
      },
    );
  }

  Future<void> onOAuthResult(
    Map<String, dynamic> result,
    SignUpMethodType type,
  ) async {
    final token = result['token'];
    if (token != null) {
      _showLoadingDialog();
      final result = await ref
          .read(authProvider.notifier)
          .oAuthLoginCallback(token);
      result.fold(
        (failure) {
          _hideLoadingDialog();
          context.showSnackBar(failure.localizedErrorMessage);
        },
        (response) {
          _hideLoadingDialog();
          ref.read(homeProvider.notifier).updateUserData(response);
          appLogger.debug(
            'OAuth login successful, for user email  ${response.legacyUserData.email}, userD ${response.legacyID}, updating app settings with token and provider: ${type.name}',
          );

          ref.read(appSettingProvider.notifier).setUserLoggedIn(true);
          navigateRoute(type, response.legacyUserData.email);
        },
      );
    } else {
      context.showSnackBar('Failed to retrieve token');
    }
  }

  //Change Email flow
  Future<void> startChangeEmailFlow(String email) async {
    _showLoadingDialog();
    final result = await ref
        .read(authProvider.notifier)
        .startChangeEmail(email, widget.password!);

    result.fold(
      (failure) {
        _hideLoadingDialog();
        AppDialog.errorDialog(
          context: context,
          title: 'error'.i18n,
          content: failure.localizedErrorMessage,
        );
      },
      (newEmail) {
        _hideLoadingDialog();
        appLogger.debug('Change email started successfully: $newEmail');
        navigateRoute(SignUpMethodType.email, email);
      },
    );
  }

  void navigateRoute(
    SignUpMethodType type,
    String email, [
    String? tempPassword,
  ]) {
    switch (type) {
      case SignUpMethodType.apple:
      case SignUpMethodType.google:
        final storeVersion = isStoreVersion();
        if (storeVersion) {
          AppDialog.showLanternProDialog(
            context: context,
            onPressed: () {
              appRouter.popUntilRoot();
            },
          );
          return;
        }
        if (widget.authFlow == AuthFlow.lanternProLicense) {
          appRouter.push(LanternProLicense(email: email, code: ''));
          return;
        }
        appRouter.push(
          ChoosePaymentMethod(email: email, authFlow: AuthFlow.oauth),
        );
        break;
      case SignUpMethodType.email:
        appRouter.push(
          ConfirmEmail(
            email: email,
            authFlow: widget.authFlow,
            password: widget.password ?? tempPassword,
          ),
        );
        break;
      case SignUpMethodType.withoutEmail:
        continueWithoutEmail();
        break;
    }
  }

  void continueWithoutEmail() {
    showEmailDialog(() async {
      try {
        _showLoadingDialog();
        await checkUserAccountStatus(ref, context);
        if (!mounted) return;
        _hideLoadingDialog();
        AppDialog.showLanternProDialog(
          context: context,
          onPressed: () {
            appRouter.popUntilRoot();
          },
        );
      } catch (e) {
        if (!mounted) return;
        _hideLoadingDialog();
        appLogger.error('Error while continuing without email: $e');
        context.showSnackBar('error_occurred'.i18n);
      }
    });
  }

  void showEmailDialog(OnPressed onContinue) {
    final size = MediaQuery.of(context).size;
    AppDialog.customDialog(
      context: context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: size.width * 0.7,
              height: 40,
              child: AutoSizeText(
                'are_you_sure'.i18n,
                style: textTheme!.headlineMedium,
                maxLines: 1,
                minFontSize: 20,
                maxFontSize: 24,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(height: defaultSize),
          Text(
            'continue_without_email_message'.i18n,
            style: textTheme!.bodyMedium,
          ),
        ],
      ),
      action: [
        AppTextButton(
          label: 'continue'.i18n,
          textColor: AppColors.gray6,
          onPressed: () {
            appRouter.maybePop();
            Future.delayed(const Duration(milliseconds: 300), onContinue);
          },
        ),
        AppTextButton(
          label: 'add_email'.i18n,
          textColor: AppColors.blue6,
          onPressed: () {
            appRouter.maybePop();
          },
        ),
      ],
    );
  }

  void _showEmailDeliverabilityNotice(OnPressed onContinue) {
    AppDialog.customDialog(
      context: context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: size24),
          Text(
            'email_deliverability_notice'.i18n,
            style: textTheme!.headlineSmall!.copyWith(
              color: context.textPrimary,
            ),
          ),
          SizedBox(height: defaultSize),
          Text(
            'email_deliverability_notice_message'.i18n,
            style: textTheme!.bodyMedium!.copyWith(color: context.textPrimary),
          ),
          SizedBox(height: defaultSize),
          Text(
            'email_deliverability_notice_message_two'.i18n,
            style: textTheme!.bodyMedium!.copyWith(color: context.textPrimary),
          ),
        ],
      ),
      action: [
        AppTextButton(
          padding: EdgeInsets.only(right: 8.0),
          label: 'change_email'.i18n,
          textColor: AppColors.gray6,
          onPressed: () {
            appRouter.maybePop();
          },
        ),
        AppTextButton(
          padding: EdgeInsets.only(right: defaultSize),
          label: 'continue_anyway'.i18n,
          textColor: AppColors.blue6,
          onPressed: () {
            appRouter.maybePop();
            Future.delayed(const Duration(milliseconds: 300), onContinue);
          },
        ),
      ],
    );
  }
}
