package common

type Command string

// only VPN related commands for Windows service
// Other commands are handled in the ffi layer directly
const (
	CmdSetupAdapter    Command = "SetupAdapter"
	CmdStartTunnel     Command = "StartTunnel"
	CmdStopTunnel      Command = "StopTunnel"
	CmdIsVPNRunning    Command = "IsVPNRunning"
	CmdConnectToServer Command = "ConnectToServer"
	CmdStopService     Command = "Stop"
	CmdWatchStatus     Command = "WatchStatus"
	CmdWatchLogs       Command = "WatchLogs"
)

const (
	WindowsServiceName = "LanternSvc"
)
