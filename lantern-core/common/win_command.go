package common

type Command string

const (
	CmdSetupAdapter Command = "SetupAdapter"
	CmdStartTunnel  Command = "StartTunnel"
	CmdStopTunnel   Command = "StopTunnel"
	CmdIsVPNRunning Command = "IsVPNRunning"
	//CmdStatus                Command = "Status"
	CmdConnectToServer       Command = "ConnectToServer"
	CmdAddSplitTunnelItem    Command = "AddSplitTunnelItem"
	CmdRemoveSplitTunnelItem Command = "RemoveSplitTunnelItem"
	CmdGetUserData           Command = "GetUserData"
	CmdFetchUserData         Command = "FetchUserData"
	CmdStopService           Command = "Stop"
	CmdWatchStatus           Command = "WatchStatus"
	CmdWatchLogs             Command = "WatchLogs"
)

const (
	WindowsServiceName = "LanternSvc"
)
