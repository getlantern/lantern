class PrivateServerStatus {
  final String status;
  final String? data;
  final String? error;

  const PrivateServerStatus({
    required this.status,
    this.data,
    this.error,
  });

  factory PrivateServerStatus.fromJson(Map<String, dynamic> json) {
    return PrivateServerStatus(
      status: (json['status'] as String?) ?? 'unknown',
      data: json['data'] as String?,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'data': data,
        'error': error,
      };

  PrivateServerStatus copyWith({
    String? status,
    String? data,
    String? error,
    bool clearData = false,
    bool clearError = false,
  }) {
    return PrivateServerStatus(
      status: status ?? this.status,
      data: clearData ? null : (data ?? this.data),
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get hasError => (error != null && error!.isNotEmpty);

  @override
  String toString() =>
      'PrivateServerStatus(status: $status, data: $data, error: $error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivateServerStatus &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          data == other.data &&
          error == other.error;

  @override
  int get hashCode => Object.hash(status, data, error);
}

class CertSummary {
  final String fingerprint;
  final String issuer;
  final String subject;

  factory CertSummary.fromJson(Map<String, dynamic> json) {
    return CertSummary(
      fingerprint: json['fingerprint'] ?? '',
      issuer: json['issuer'] ?? '',
      subject: json['subject'] ?? '',
    );
  }

  CertSummary(
      {required this.fingerprint, required this.issuer, required this.subject});
}
