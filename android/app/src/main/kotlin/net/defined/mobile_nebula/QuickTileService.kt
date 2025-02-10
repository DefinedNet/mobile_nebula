package net.defined.mobile_nebula

import android.app.PendingIntent
import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.graphics.drawable.Icon
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import android.os.RemoteException
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log

class QuickTileService : TileService() {
    private var inMessenger: Messenger? = Messenger(IncomingHandler())
    private var outMessenger: Messenger? = null

    override fun onBind(intent: Intent?): IBinder? {
        Log.d(TAG, "!!! QuickTileService onBind")
        var ret = super.onBind(intent)
        requestListeningState(this, ComponentName(this, QuickTileService::class.java))
        return ret
    }

    override fun onCreate() {
        Log.d(TAG, "!!! QuickTileService onCreate")
        super.onCreate()
    }

    override fun onDestroy() {
        super.onDestroy()
    }

    override fun onClick() {
        Log.d(TAG, "!!! QuickTileService onClick ${qsTile.state == Tile.STATE_ACTIVE}")
        super.onClick()

        var klass =
                if (qsTile.state == Tile.STATE_ACTIVE) {
                    StopVpnActivity::class.java
                } else {
                    StartVpnActivity::class.java
                }
        var intent =
                Intent(this, klass).apply { //
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }

        startActivityAndCollapse(
                PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)
        )
    }

    override fun onTileAdded() {
        Log.d(TAG, "!!! QuickTileService onTileAdded")
        super.onTileAdded()
    }

    override fun onTileRemoved() {
        Log.d(TAG, "!!! QuickTileService onTileRemoved")
        super.onTileRemoved()
    }

    fun updateTile(state: Int) {
        Log.d(TAG, "!!! QuickTileService updateTile ${state}")

        qsTile.state = state
        qsTile.updateTile()
    }

    override fun onStartListening() {
        Log.d(TAG, "!!! QuickTileService onStartListening")
        super.onStartListening()

        updateTile(Tile.STATE_UNAVAILABLE)

        val sites = SiteList.getSites(this, this.filesDir)
        if (sites.count() == 0) {
            return
        }

        var site = sites.values.first()
        Log.d(TAG, "!!! QuickTileService onStartListening ${site.connected} ${site.status}")
        updateTile(
                when (site.connected) {
                    true -> Tile.STATE_ACTIVE
                    false -> Tile.STATE_INACTIVE
                    null -> Tile.STATE_UNAVAILABLE
                }
        )

        val intent = Intent(this, NebulaVpnService::class.java)
        bindService(intent, connection, 0)
    }

    override fun onStopListening() {
        Log.d(TAG, "!!! QuickTileService onStopListening")
        super.onStopListening()

        unbindVpnService()
    }

    private fun unbindVpnService() {
        if (outMessenger != null) {
            // Unregister ourselves
            val msg = Message.obtain(null, NebulaVpnService.MSG_UNREGISTER_CLIENT)
            msg.replyTo = inMessenger
            outMessenger!!.send(msg)
            // Unbind
            unbindService(connection)
        }
        outMessenger = null
    }

    /** Defines callbacks for service binding, passed to bindService() */
    private val connection =
            object : ServiceConnection {
                override fun onServiceConnected(className: ComponentName, service: IBinder) {
                    Log.d(TAG, "!!! onServiceConnected: ${className} ${service}")

                    outMessenger = Messenger(service)

                    // We want to monitor the service for as long as we are connected to it.
                    try {
                        val msg = Message.obtain(null, NebulaVpnService.MSG_REGISTER_CLIENT)
                        msg.replyTo = inMessenger
                        outMessenger!!.send(msg)
                    } catch (e: RemoteException) {
                        // In this case the service has crashed before we could even
                        // do anything with it; we can count on soon being
                        // disconnected (and then reconnected if it can be restarted)
                        // so there is no need to do anything here.
                        // TODO:
                    }

                    val msg = Message.obtain(null, NebulaVpnService.MSG_IS_RUNNING)
                    outMessenger!!.send(msg)
                }

                override fun onServiceDisconnected(className: ComponentName) {
                    Log.d(TAG, "!!! onServiceDisconnected: ${className}")

                    outMessenger = null
                    // if (activeSiteId != null) {
                    //     // TODO: this indicates the service died, notify that it is disconnected
                    // }
                    // activeSiteId = null

                    updateTile(Tile.STATE_INACTIVE)
                }
            }

    // Handle and route messages coming from the vpn service
    inner class IncomingHandler : Handler(Looper.getMainLooper()) {
        override fun handleMessage(msg: Message) {

            when (msg.what) {
                NebulaVpnService.MSG_IS_RUNNING -> isRunning(msg.arg1 == 1)
                NebulaVpnService.MSG_EXIT -> serviceExited()
                else -> super.handleMessage(msg)
            }
        }

        private fun isRunning(running: Boolean) {
            updateTile(
                    if (running) {
                        Tile.STATE_ACTIVE
                    } else {
                        Tile.STATE_INACTIVE
                    }
            )
        }

        private fun serviceExited() {
            updateTile(Tile.STATE_INACTIVE)
            unbindVpnService()
        }
    }

    companion object {
        fun askAddTile(context: Context) {
            Log.d(TAG, "!!! askAddTile")

            val statusBarManager = context.getSystemService(StatusBarManager::class.java)
            statusBarManager.requestAddTileService(
                    ComponentName(context, QuickTileService::class.java),
                    context.getString(R.string.quick_tile_label),
                    Icon.createWithResource(context, R.drawable.quick_tile_icon),
                    context.mainExecutor
            ) { //
                Log.d(TAG, "requestAddTileService result: $it")
            }
        }
    }
}
