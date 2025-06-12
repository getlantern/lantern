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
