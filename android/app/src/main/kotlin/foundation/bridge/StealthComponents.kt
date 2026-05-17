package foundation.bridge

import androidx.annotation.RequiresApi
import org.getlantern.lantern.LanternApp
import org.getlantern.lantern.MainActivity
import org.getlantern.lantern.service.LanternVpnService
import org.getlantern.lantern.service.QuickTileService

class AppHost : LanternApp()

class HomeActivity : MainActivity()

class NetworkService : LanternVpnService()

@RequiresApi(24)
class ControlTile : QuickTileService()
