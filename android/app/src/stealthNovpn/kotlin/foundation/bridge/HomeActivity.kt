package foundation.bridge

class HomeActivity : BaseHomeActivity() {
    override suspend fun connect() {
        BridgeState.set("connecting")
        startAction(SyncService::class.java, SyncService.ACTION_CONNECT)
    }

    override suspend fun disconnect() {
        BridgeState.set("disconnecting")
        startAction(SyncService::class.java, SyncService.ACTION_DISCONNECT)
    }
}
