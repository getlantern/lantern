class PrivateServerStatus {
  final String status;
  String? data;
  String? error;

  factory PrivateServerStatus.fromJson(Map<String, dynamic> json) {
    return PrivateServerStatus(
      status: json['status'] ?? 'unknown',
      data: json['data'],
      error: json['error'],
    );
  }

  PrivateServerStatus({required this.status, this.data, this.error});
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
