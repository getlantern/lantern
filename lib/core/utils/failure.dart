class Failure {
  final String error;
  final String localizedErrorMessage;

  Failure({required this.error, required this.localizedErrorMessage});

  @override
  String toString() =>
      'Failure(error: $error, localizedErrorMessage: $localizedErrorMessage)';
}
