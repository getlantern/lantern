package foundation.bridge

import android.content.Intent
import android.net.VpnService

class HomeActivity : BaseHomeActivity() {
    companion object {
        private const val PREPARE_REQUEST = 3917
    }

    override suspend fun connect() {
        val prepareIntent = VpnService.prepare(this)
        if (prepareIntent != null) {
            startActivityForResult(prepareIntent, PREPARE_REQUEST)
            return
        }
        BridgeState.set("connecting")
        startAction(NetworkService::class.java, NetworkService.ACTION_CONNECT)
    }

    override suspend fun disconnect() {
        BridgeState.set("disconnecting")
        startAction(NetworkService::class.java, NetworkService.ACTION_DISCONNECT)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PREPARE_REQUEST && resultCode == RESULT_OK) {
            BridgeState.set("connecting")
            startAction(NetworkService::class.java, NetworkService.ACTION_CONNECT)
        }
    }
}
