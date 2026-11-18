class Website {
  const Website({required this.domain});

  final String domain;

  String get displayDomain => domain.startsWith('.') ? '*$domain' : domain;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Website && other.domain == domain;

  @override
  int get hashCode => domain.hashCode;

  @override
  String toString() => 'Website($domain)';
}
