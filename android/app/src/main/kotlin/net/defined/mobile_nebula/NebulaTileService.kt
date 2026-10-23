package net.defined.mobile_nebula

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import org.json.JSONObject
import java.io.File


// Toggles the last site that ran, picking another site is done by starting it in the app
class NebulaTileService : TileService() {

    companion object {
        const val TAG = "NebulaTileService"

        // The tile has no ui to bind to the service with, so the service is asked to start the vpn right away
        fun startSite(context: Context, path: String) {
            context.startService(Intent(context, NebulaVpnService::class.java).apply {
                putExtra("path", path)
                putExtra("autoStart", true)
            })
            // Lets an open app attach to the service so it shows the site as connected
            context.sendBroadcast(Intent(MainActivity.ACTION_REFRESH_SITES).setPackage(context.packageName))
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        updateTile(isVpnRunning())
    }

    override fun onClick() {
        super.onClick()

        // Don't let anyone holding a locked phone turn the vpn on or off
        if (isLocked) {
            return unlockAndRun { toggle() }
        }
        toggle()
    }

    private fun toggle() {
        if (isVpnRunning()) {
            try {
                startService(Intent(this, NebulaVpnService::class.java).apply {
                    action = NebulaVpnService.ACTION_STOP
                })
            } catch (err: IllegalStateException) {
                Log.e(TAG, "Could not stop the vpn service: $err")
                return openActivity(Intent(this, MainActivity::class.java))
            }
            updateTile(false)
            return
        }

        // Without a site that ran before or vpn permission the user has to start a site in the app first
        val path = lastSitePath()
        if (path == null || VpnService.prepare(this) != null) {
            return openActivity(Intent(this, MainActivity::class.java))
        }

        try {
            startSite(this, path)
        } catch (err: IllegalStateException) {
            // Android won't let a backgrounded app start a service, a short lived activity brings us to the foreground
            Log.i(TAG, "Starting the vpn through TileStartActivity: $err")
            openActivity(Intent(this, TileStartActivity::class.java).putExtra("path", path))
        }
        // Assume it worked, onStartListening shows the real state the next time the panel opens
        updateTile(true)
    }

    private fun updateTile(active: Boolean) {
        val tile = qsTile ?: return
        tile.label = lastSiteName() ?: getString(R.string.app_name)
        tile.state = if (active) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.updateTile()
    }

    // Null when no site ran yet or it was deleted since
    private fun lastSitePath(): String? {
        val path = try { filesDir.resolve("last-site").readText() } catch (_: Exception) { return null }
        return if (File(path, "config.json").exists()) path else null
    }

    private fun lastSiteName(): String? {
        val path = lastSitePath() ?: return null
        return try {
            JSONObject(File(path, "config.json").readText()).optString("name").ifEmpty { null }
        } catch (_: Exception) {
            null
        }
    }

    // The vpn service runs in its own process so we can't ask it directly, look for a vpn network we own instead.
    // Every network is checked since we exclude ourselves from the vpn and activeNetwork never reports it.
    @Suppress("DEPRECATION")
    private fun isVpnRunning(): Boolean {
        // Without vpn permission none of the vpns can be ours
        if (VpnService.prepare(this) != null) {
            return false
        }
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        return connectivityManager.allNetworks.any { network ->
            val caps = connectivityManager.getNetworkCapabilities(network) ?: return@any false
            // ownerUid tells our vpn apart from one in another profile, it is only available on Q+
            caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) &&
                    (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || caps.ownerUid == Process.myUid())
        }
    }

    private fun openActivity(intent: Intent) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}

// Invisible activity the tile uses to start a site when Android won't let the backgrounded app start services
class TileStartActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent.getStringExtra("path")?.let { NebulaTileService.startSite(this, it) }
        finish()
    }
}
