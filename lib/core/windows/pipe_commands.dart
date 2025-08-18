enum ServiceCommand {
  setupAdapter,
  startTunnel,
  stopTunnel,
  connectToServer,
  isVPNRunning,
  status,
}

extension ServiceCommandWire on ServiceCommand {
  String get wire => switch (this) {
        ServiceCommand.setupAdapter => 'SetupAdapter',
        ServiceCommand.startTunnel => 'StartTunnel',
        ServiceCommand.stopTunnel => 'StopTunnel',
        ServiceCommand.connectToServer => 'ConnectToServer',
        ServiceCommand.isVPNRunning => 'IsVPNRunning',
        ServiceCommand.status => 'Status',
      };
}
