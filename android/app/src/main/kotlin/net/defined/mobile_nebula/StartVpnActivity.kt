package net.defined.mobile_nebula

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.ServiceConnection
import android.net.VpnService
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import android.os.RemoteException
import android.util.Log

class StartVpnActivity : Activity() {
    private var inMessenger: Messenger? = Messenger(IncomingHandler())
    private var outMessenger: Messenger? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        Log.d(TAG, "!!! StartVpnActivity onCreate")
        super.onCreate(savedInstanceState)

        val intent = VpnService.prepare(this)
        if (intent != null) {
            startActivityForResult(intent, VPN_START_CODE)
        } else {
            onActivityResult(VPN_START_CODE, Activity.RESULT_OK, null)
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "!!! StartVpnActivity onDestroy")
        unbindVpnService()
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        Log.d(TAG, "!!! StartVpnActivity onActivityResult ${requestCode == VPN_START_CODE}")

        // This is where activity results come back to us (startActivityForResult)
        if (requestCode == VPN_START_CODE) {
            val sites = SiteList.getSites(this, this.filesDir)
            Log.d(TAG, "!!! StartVpnActivity onActivityResult VPN_START_CODE ${sites.count() == 0}")
            if (sites.count() == 0) {
                var intent =
                        Intent(this, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                startActivity(intent)
            } else {
                var site = sites.values.first()
                val intent =
                        Intent(this, NebulaVpnService::class.java).apply {
                            putExtra("path", site.path)
                            putExtra("id", site.id)
                        }
                Log.d(TAG, "!!! startService for site '${site.name}'")
                var ret = startService(intent)
                Log.d(TAG, "!!! startService: ${ret}")

                val bindIntent = Intent(this, NebulaVpnService::class.java)
                bindService(bindIntent, connection, 0)
            }
        }
    }

    override fun finish() {
        Log.d(TAG, "!!! StartVpnActivity finish")
        super.finish()
    }

    private fun unbindVpnService() {
        if (outMessenger != null) {
            // Unregister ourselves
            val msg = Message.obtain(null, NebulaVpnService.MSG_UNREGISTER_CLIENT)
            msg.replyTo = inMessenger
            outMessenger!!.send(msg)
            // Unbind
            unbindService(connection)

            outMessenger = null
        }
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
            if (running) {
                finish()
            }
        }

        private fun serviceExited() {
            unbindVpnService()
        }
    }
}
