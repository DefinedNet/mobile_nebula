package net.defined.mobile_nebula

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.*
import android.os.*
import android.util.Log
import androidx.annotation.RequiresApi
import mobileNebula.CIDR
import java.io.File


class NebulaVpnService : VpnService() {

    companion object {
        private const val TAG = "NebulaVpnService"
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

    private var running: Boolean = false
    private var site: Site? = null
    private var nebula: mobileNebula.Nebula? = null
    private var vpnInterface: ParcelFileDescriptor? = null
    private var didSleep = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.getStringExtra("COMMAND") == "STOP") {
            stopVpn()
            return Service.START_NOT_STICKY
        }

        val path = intent?.getStringExtra("path")
        val id = intent?.getStringExtra("id")
        
        if (running) {
            announceExit(id, "Trying to run nebula but it is already running")
            //TODO: can we signal failure?
            return super.onStartCommand(intent, flags, startId)
        }

        //TODO: if we fail to start, android will attempt a restart lacking all the intent data we need.
        // Link active site config in Main to avoid this
        site = Site(File(path))

        if (site!!.cert == null) {
            announceExit(id, "Site is missing a certificate")
            //TODO: can we signal failure?
            return super.onStartCommand(intent, flags, startId)
        }

        // We don't actually start here. In order to properly capture boot errors we wait until an IPC connection is made

        return super.onStartCommand(intent, flags, startId)
    }

    private fun startVpn() {
        var ipNet: CIDR

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

        // Add our unsafe routes
        site!!.unsafeRoutes.forEach { unsafeRoute ->
            val ipNet = mobileNebula.MobileNebula.parseCIDR(unsafeRoute.route)
            builder.addRoute(ipNet.network, ipNet.maskSize.toInt())
        }

        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        cm.allNetworks.forEach { network ->
            cm.getLinkProperties(network).dnsServers.forEach { builder.addDnsServer(it) }
        }

        try {
            vpnInterface = builder.establish()
            nebula = mobileNebula.MobileNebula.newNebula(site!!.config, site!!.getKey(this), site!!.logFile, vpnInterface!!.fd.toLong())

        } catch (e: Exception) {
            Log.e(TAG, "Got an error $e")
            vpnInterface?.close()
            announceExit(site!!.id, e.message)
            return stopSelf()
        }

        registerNetworkCallback()
        registerSleep()
        
        nebula!!.start()
        running = true
        sendSimple(MSG_IS_RUNNING, if (running) 1 else 0)
    }

    // Used to detect network changes (wifi -> cell or vice versa) and rebinds the udp socket/updates LH
    private fun registerNetworkCallback() {
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        val builder = NetworkRequest.Builder()
        builder.addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)

        connectivityManager.registerNetworkCallback(builder.build(),
                object : ConnectivityManager.NetworkCallback () {
                    override fun onAvailable(network: Network?) {
                        super.onAvailable(network)
                        nebula!!.rebind("network change")
                    }

                    override fun onLost(network: Network?) {
                        super.onLost(network)
                        nebula!!.rebind("network change")
                    }
                })
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

    private fun stopVpn() {
        nebula?.stop()
        vpnInterface?.close()
        running = false
        announceExit(site?.id, null)
    }

    override fun onDestroy()  {
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

    /**
     * Handler of incoming messages from clients.
     */
    inner class IncomingHandler(context: Context, private val applicationContext: Context = context.applicationContext) : Handler() {
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
            var m = Message.obtain(null, msg.what)
            m.data.putString("data", res)
            msg.replyTo.send(m)
        }
        
        private fun getHostInfo(msg: Message) {
            if (protect(msg)) { return }

            val res = nebula!!.getHostInfoByVpnIp(msg.data.getString("vpnIp"), msg.data.getBoolean("pending"))
            var m = Message.obtain(null, msg.what)
            m.data.putString("data", res)
            msg.replyTo.send(m)
        }

        private fun setRemoteForTunnel(msg: Message) {
            if (protect(msg)) { return }

            val res = nebula!!.setRemoteForTunnel(msg.data.getString("vpnIp"), msg.data.getString("addr"))
            var m = Message.obtain(null, msg.what)
            m.data.putString("data", res)
            msg.replyTo.send(m)
        }
        
        private fun closeTunnel(msg: Message) {
            if (protect(msg)) { return }

            val res = nebula!!.closeTunnel(msg.data.getString("vpnIp"))
            var m = Message.obtain(null, msg.what)
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

        messenger = Messenger(IncomingHandler(this))
        return messenger.binder
    }
}