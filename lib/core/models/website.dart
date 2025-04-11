import 'package:objectbox/objectbox.dart';

@Entity()
class Website {
  int id;
  final String domain;

  Website({
    this.id = 0,
    required this.domain,
  });

  Website copyWith({
    int? id,
    String? domain,
    bool? isEnabled,
  }) {
    return Website(
      id: id ?? this.id,
      domain: domain ?? this.domain,
    );
  }

  factory Website.fromJson(Map<String, dynamic> json) {
    return Website(
      id: json['id'] ?? '',
      domain: json['domain'] ?? '',
    );
  }
}
