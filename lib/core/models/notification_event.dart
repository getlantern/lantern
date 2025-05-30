enum NotificationEvent {
  dataCapLimit,
  vpnConnected,
  vpnDisconnected,
  subscriptionExpired,
  updateAvailable,
}

extension NotificationEventId on NotificationEvent {
  int get id {
    switch (this) {
      case NotificationEvent.vpnConnected:
        return 1001;
      case NotificationEvent.vpnDisconnected:
        return 1002;
      case NotificationEvent.subscriptionExpired:
        return 1003;
      case NotificationEvent.updateAvailable:
        return 1004;
      case NotificationEvent.dataCapLimit:
        return 1005;
    }
  }
}
