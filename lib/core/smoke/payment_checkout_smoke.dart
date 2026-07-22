class PaymentCheckoutSmokeConfig {
  static const _providerPrefix = '--payment-checkout-smoke=';
  static const _runIDPrefix = '--payment-checkout-run-id=';
  static final _runIDPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
    r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final String provider;
  final String runID;

  const PaymentCheckoutSmokeConfig({
    required this.provider,
    required this.runID,
  });

  String get email => 'e2e+$runID@getlantern.org';

  static PaymentCheckoutSmokeConfig? parse(
    List<String> arguments, {
    required bool isWindows,
    required String buildType,
  }) {
    final providerArgument = _singleArgument(arguments, _providerPrefix);
    final runIDArgument = _singleArgument(arguments, _runIDPrefix);

    if (providerArgument == null && runIDArgument == null) {
      return null;
    }
    if (!isWindows || buildType != 'nightly') {
      throw const FormatException(
        'Payment checkout smoke mode is available only in Windows nightly builds',
      );
    }
    if (providerArgument == null || runIDArgument == null) {
      throw const FormatException(
        'Payment checkout smoke mode requires a provider and run ID',
      );
    }

    final provider = providerArgument.toLowerCase();
    if (provider != 'stripe' && provider != 'shepherd') {
      throw FormatException('Unsupported payment checkout provider: $provider');
    }
    if (!_runIDPattern.hasMatch(runIDArgument)) {
      throw const FormatException('Invalid payment checkout smoke run ID');
    }

    return PaymentCheckoutSmokeConfig(provider: provider, runID: runIDArgument);
  }

  static String? _singleArgument(List<String> arguments, String prefix) {
    final matches = arguments.where((argument) => argument.startsWith(prefix));
    if (matches.length > 1) {
      throw FormatException('Argument may be specified only once: $prefix');
    }
    if (matches.isEmpty) {
      return null;
    }
    final value = matches.single.substring(prefix.length).trim();
    return value.isEmpty ? null : value;
  }
}
