class Website {
  final int id;
  final String domain;

  const Website({
    this.id = 0,
    required this.domain,
  });

  Website copyWith({
    int? id,
    String? domain,
  }) {
    return Website(
      id: id ?? this.id,
      domain: domain ?? this.domain,
    );
  }

  factory Website.fromJson(Map<String, dynamic> json) {
    return Website(
      id: (json['id'] as num?)?.toInt() ?? 0,
      domain: (json['domain'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'domain': domain,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Website && other.domain == domain;

  @override
  int get hashCode => domain.hashCode;

  @override
  String toString() => 'Website(id: $id, domain: $domain)';
}
