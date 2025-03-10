class Website {
  final String domain;
  final bool isEnabled;

  Website({
    required this.domain,
    required this.isEnabled,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Website && other.domain == domain);

  @override
  int get hashCode => domain.hashCode;

  Map<String, dynamic> toJson() => {
        "domain": domain,
        "isEnabled": isEnabled,
      };

  Website copyWith({
    String? domain,
    bool? isEnabled,
  }) {
    return Website(
      domain: domain ?? this.domain,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  factory Website.fromJson(Map<String, dynamic> json) {
    return Website(
      domain: json["domain"],
      isEnabled: json["isEnabled"] ?? false,
    );
  }
}
