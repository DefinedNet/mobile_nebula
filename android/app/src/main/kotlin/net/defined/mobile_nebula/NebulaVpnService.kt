package net.defined.mobile_nebula

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.*
import android.os.*
import android.system.OsConstants
import android.util.Log
import androidx.work.*
import mobileNebula.CIDR
import java.io.File


class NebulaVpnService : VpnService() {

    companion object {
        const val TAG = "NebulaVpnService"

        const val ACTION_STOP = "net.defined.mobile_nebula.STOP"
        const val ACTION_RELOAD = "net.defined.mobile_nebula.RELOAD"

        const val MSG_REGISTER_CLIENT = 1
        const val MSG_UNREGISTER_CLIENT = 2
        const val MSG_IS_RUNNING = 3
        const val MSG_LIST_HOSTMAP = 4
        const val MSG_LIST_PENDING_HOSTMAP = 5
        const val MSG_GET_HOSTINFO = 6
        const val MSG_SET_REMOTE_FOR_TUNNEL = 7
        const val MSG_CLOSE_TUNNEL = 8
        const val MSG_EXIT = 9
    }

    /**
     * Target we publish for clients to send messages to IncomingHandler.
     */
    private lateinit var messenger: Messenger
    private val mClients = ArrayList<Messenger>()

    private val reloadReceiver: BroadcastReceiver = ReloadReceiver()
    private var workManager: WorkManager? = null

    private var path: String? = null
    private var running: Boolean = false
    private var site: Site? = null
    private var nebula: mobileNebula.Nebula? = null
    private var vpnInterface: ParcelFileDescriptor? = null
    private var didSleep = false
    private var networkCallback: NetworkCallback = NetworkCallback()

    override fun onCreate() {
        workManager = WorkManager.getInstance(this)
        super.onCreate()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopVpn()
            return Service.START_NOT_STICKY
        }

        val id = intent?.getStringExtra("id")

        if (running) {
            // if the UI triggers this twice, check if we are already running the requested site. if not, return an error.
            // otherwise, just ignore the request since we handled it the first time.
            if (site!!.id != id) {
                announceExit(id, "Trying to run nebula but it is already running")
            }

            //TODO: can we signal failure?
            return super.onStartCommand(intent, flags, startId)
        }

        path = intent!!.getStringExtra("path")!!
        //TODO: if we fail to start, android will attempt a restart lacking all the intent data we need.
        // Link active site config in Main to avoid this
        site = Site(this, File(path!!))

        if (site!!.cert == null) {
            announceExit(id, "Site is missing a certificate")
            //TODO: can we signal failure?
            return super.onStartCommand(intent, flags, startId)
        }

        // Kick off a site update
        val workRequest = OneTimeWorkRequestBuilder<DNUpdateWorker>().build()
        workManager!!.enqueue(workRequest)

        // We don't actually start here. In order to properly capture boot errors we wait until an IPC connection is made

        return super.onStartCommand(intent, flags, startId)
    }

    private fun startVpn() {
        val ipNet: CIDR

        try {
            ipNet = mobileNebula.MobileNebula.parseCIDR(site!!.cert!!.cert.details.ips[0])
        } catch (err: Exception) {
            return announceExit(site!!.id, err.message ?: "$err")
        }

        val builder = Builder()
                .addAddress(ipNet.ip, ipNet.maskSize.toInt())
                .addRoute(ipNet.network, ipNet.maskSize.toInt())
                .setMtu(site!!.mtu)
                .setSession(TAG)
                .allowFamily(OsConstants.AF_INET)
                .allowFamily(OsConstants.AF_INET6)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        // Disallow some common, known-problematic apps
        // TODO Make this user configurable
        // Ensure that a misconfigured unsafe_route doesn't block access to the DN API
        disallowApp(builder, "net.defined.mobile_nebula")
        disallowApp(builder, "net.defined.mobile_nebula.debug")
        // Android Auto Wireless (https://github.com/DefinedNet/mobile_nebula/issues/102)
        disallowApp(builder, "com.google.android.projection.gearhead")
        // Chromecast (https://github.com/DefinedNet/mobile_nebula/issues/102)
        disallowApp(builder, "com.google.android.apps.chromecast.app")
        // RCS / Jibe
        disallowApp(builder, "com.google.android.apps.messaging")

        // Add our unsafe routes
        site!!.unsafeRoutes.forEach { unsafeRoute ->
            val unsafeIPNet = mobileNebula.MobileNebula.parseCIDR(unsafeRoute.route)
            builder.addRoute(unsafeIPNet.network, unsafeIPNet.maskSize.toInt())
        }

        try {
            vpnInterface = builder.establish()
            nebula = mobileNebula.MobileNebula.newNebula(site!!.config, site!!.getKey(this), site!!.logFile, vpnInterface!!.detachFd().toLong())

        } catch (e: Exception) {
            Log.e(TAG, "Got an error $e")
            vpnInterface?.close()
            announceExit(site!!.id, e.message)
            return stopSelf()
        }

        registerNetworkCallback()
        registerReloadReceiver()
        //TODO: There is an open discussion around sleep killing tunnels or just changing mobile to tear down stale tunnels
        //registerSleep()

        nebula!!.start()
        running = true
        sendSimple(MSG_IS_RUNNING, 1)
    }

    private fun disallowApp(builder: Builder, name: String) {
        try {
            builder.addDisallowedApplication(name)
        } catch (e: PackageManager.NameNotFoundException) {
            return
        }
    }


    // Used to detect network changes (wifi -> cell or vice versa) and rebinds the udp socket/updates LH
    private fun registerNetworkCallback() {
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        val builder = NetworkRequest.Builder()
        builder.addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)

        connectivityManager.registerNetworkCallback(builder.build(), networkCallback)
    }

    private fun unregisterNetworkCallback() {
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        connectivityManager.unregisterNetworkCallback(networkCallback)
    }

    inner class NetworkCallback : ConnectivityManager.NetworkCallback () {
        override fun onAvailable(network: Network) {
            super.onAvailable(network)
            nebula!!.rebind("network change")
        }

        override fun onLost(network: Network) {
            super.onLost(network)
            nebula!!.rebind("network change")
        }
    }


    private fun registerSleep() {
        val receiver: BroadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent?) {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                if (pm.isDeviceIdleMode) {
                    if (!didSleep) {
                        nebula!!.sleep()
                        //TODO: we may want to shut off our network change listener like we do with iOS, I haven't observed any issues with it yet though
                    }
                    didSleep = true
                } else {
                    nebula!!.rebind("android wake")
                    didSleep = false
                }
            }
        }

        registerReceiver(receiver, IntentFilter(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED))
    }

    private fun registerReloadReceiver() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(reloadReceiver, IntentFilter(ACTION_RELOAD), RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(reloadReceiver, IntentFilter(ACTION_RELOAD))
        }
    }

    private fun unregisterReloadReceiver() {
        unregisterReceiver(reloadReceiver)
    }

    private fun reload() {
        site = Site(this, File(path!!))
        nebula?.reload(site!!.config, site!!.getKey(this))
    }

    private fun stopVpn() {
        if (nebula == null) {
            return stopSelf()
        }

        unregisterNetworkCallback()
        unregisterReloadReceiver()
        nebula?.stop()
        nebula = null
        running = false
        announceExit(site?.id, null)
        stopSelf()
    }

    override fun onRevoke()  {
        stopVpn()
        //TODO: wait for the thread to exit
        super.onRevoke()
    }

    override fun onDestroy() {
        stopVpn()
        //TODO: wait for the thread to exit
        super.onDestroy()
    }

    private fun announceExit(id: String?, err: String?) {
        val msg = Message.obtain(null, MSG_EXIT)
        if (err != null) {
            msg.data.putString("error", err)
            Log.e(TAG, "$err")
        }
        send(msg, id)
    }

    inner class ReloadReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent?) {
            if (intent?.action != ACTION_RELOAD) return
            if (!running) return
            if (intent.getStringExtra("id") != site!!.id) return

            Log.d(TAG, "Reloading Nebula")

            reload()
        }
    }

    /**
     * Handler of incoming messages from clients.
     */
    inner class IncomingHandler : Handler(Looper.getMainLooper()) {
        override fun handleMessage(msg: Message) {
            //TODO: how do we limit what can talk to us?
            //TODO: Make sure replyTo is actually a messenger
            when (msg.what) {
                MSG_REGISTER_CLIENT -> register(msg)
                MSG_UNREGISTER_CLIENT -> mClients.remove(msg.replyTo)
                MSG_IS_RUNNING -> isRunning()
                MSG_LIST_HOSTMAP -> listHostmap(msg)
                MSG_LIST_PENDING_HOSTMAP -> listHostmap(msg)
                MSG_GET_HOSTINFO -> getHostInfo(msg)
                MSG_CLOSE_TUNNEL -> closeTunnel(msg)
                MSG_SET_REMOTE_FOR_TUNNEL -> setRemoteForTunnel(msg)
                else -> super.handleMessage(msg)
            }
        }

        private fun register(msg: Message) {
            mClients.add(msg.replyTo)
            if (!running) {
                startVpn()
            }
        }

        private fun protect(msg: Message): Boolean {
            if (nebula != null) {
                return false
            }

            msg.replyTo.send(Message.obtain(null, msg.what))
            return true
        }

        private fun isRunning() {
            sendSimple(MSG_IS_RUNNING, if (running) 1 else 0)
        }

        private fun listHostmap(msg: Message) {
            if (protect(msg)) { return }

            val res = nebula!!.listHostmap(msg.what == MSG_LIST_PENDING_HOSTMAP)
            val m = Message.obtain(null, msg.what)
            m.data.putString("data", res)
            msg.replyTo.send(m)
        }

        private fun getHostInfo(msg: Message) {
            if (protect(msg)) { return }

            val res = nebula!!.getHostInfoByVpnIp(msg.data.getString("vpnIp"), msg.data.getBoolean("pending"))
            val m = Message.obtain(null, msg.what)
            m.data.putString("data", res)
            msg.replyTo.send(m)
        }

        private fun setRemoteForTunnel(msg: Message) {
            if (protect(msg)) { return }

            val res = nebula!!.setRemoteForTunnel(msg.data.getString("vpnIp"), msg.data.getString("addr"))
            val m = Message.obtain(null, msg.what)
            m.data.putString("data", res)
            msg.replyTo.send(m)
        }

        private fun closeTunnel(msg: Message) {
            if (protect(msg)) { return }

            val res = nebula!!.closeTunnel(msg.data.getString("vpnIp"))
            val m = Message.obtain(null, msg.what)
            m.data.putBoolean("data", res)
            msg.replyTo.send(m)
        }
    }

    private fun sendSimple(type: Int, arg1: Int = 0, arg2: Int = 0) {
        send(Message.obtain(null, type, arg1, arg2))
    }

    private fun sendObj(type: Int, obj: Any?) {
        send(Message.obtain(null, type, obj))
    }

    private fun send(msg: Message, id: String? = null) {
        msg.data.putString("id", id ?: site?.id)
        mClients.forEach { m ->
            try {
                m.send(msg)
            } catch (e: RemoteException) {
                // The client is dead.  Remove it from the list;
                // we are going through the list from back to front
                // so this is safe to do inside the loop.
                //TODO: seems bad to remove in loop, double check this is ok
//                mClients.remove(m)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        if (intent != null && SERVICE_INTERFACE == intent.action) {
            return super.onBind(intent)
        }

        messenger = Messenger(IncomingHandler())
        return messenger.binder
    }
}
