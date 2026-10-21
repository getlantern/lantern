# Stealth no-VPN release builds must not ship the VpnService or quick tile.
# scripts/stealth/debrand_kotlin.py rewrites these names to the de-branded
# classes Gradle compiles; a rule with no matching class would pass silently.
-checkdiscard class org.getlantern.lantern.service.LanternVpnService
-checkdiscard class org.getlantern.lantern.service.QuickTileService
