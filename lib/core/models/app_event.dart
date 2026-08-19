class AppEvent {
  static const String userMessageAvailable = 'user-message-available';

  final String eventType;
  final String message;

  AppEvent({required this.eventType, required this.message});

  factory AppEvent.fromJson(Map<String, dynamic> json) {
    return AppEvent(
      eventType: json['type'],
      message: json['message'],
    );
  }
}
