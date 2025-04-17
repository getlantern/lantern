enum VPNStatus{
  connected,
  disconnected,
  connecting,
  disconnecting,
  missingPermission,
  error,
}



enum AuthFlow{
  resetPassword,
  signUp,
  activationCode
}

enum StipeSubscriptionType{
  monthly,
  yearly,
  oneTime
}