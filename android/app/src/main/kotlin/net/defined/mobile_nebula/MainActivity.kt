package net.defined.mobile_nebula

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.VpnService
import android.os.*
import androidx.annotation.NonNull
import com.google.gson.Gson
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

const val TAG = "nebula"
const val VPN_PERMISSIONS_CODE = 0x0F
const val VPN_START_CODE = 0x10
const val CHANNEL = "net.defined.mobileNebula/NebulaVpnService"

class MainActivity: FlutterActivity() {
    private var sites: Sites? = null
    private var permResult: MethodChannel.Result? = null

    private var inMessenger: Messenger? = Messenger(IncomingHandler())
    private var outMessenger: Messenger? = null

    private var activeSiteId: String? = null

    companion object {
        private var appContext: Context? = null
        fun getContext(): Context? { return appContext }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        appContext = context
        //TODO: Initializing in the constructor leads to a context lacking info we need, figure out the right way to do this
        sites = Sites(flutterEngine)
        
        // Bind against our service to detect which site is running on app boot
        val intent = Intent(this, NebulaVpnService::class.java)
        bindService(intent, connection, 0)
        
        GeneratedPluginRegistrant.registerWith(flutterEngine);

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when(call.method) {
                "android.requestPermissions" -> androidPermissions(result)

                "nebula.parseCerts" -> nebulaParseCerts(call, result)
                "nebula.generateKeyPair" -> nebulaGenerateKeyPair(result)
                "nebula.renderConfig" -> nebulaRenderConfig(call, result)

                "listSites" -> listSites(result)
                "deleteSite" -> deleteSite(call, result)
                "saveSite" -> saveSite(call, result)
                "startSite" -> startSite(call, result)
                "stopSite" -> stopSite()

                "active.listHostmap" -> activeListHostmap(call, result)
                "active.listPendingHostmap" -> activeListPendingHostmap(call, result)
                "active.getHostInfo" -> activeGetHostInfo(call, result)
                "active.setRemoteForTunnel" -> activeSetRemoteForTunnel(call, result)
                "active.closeTunnel" -> activeCloseTunnel(call, result)

                "share" -> Share.share(call, result)
                "shareFile" -> Share.shareFile(call, result)

                else -> result.notImplemented()
            }
        }
    }

    private fun nebulaParseCerts(call: MethodCall, result: MethodChannel.Result) {
        val certs = call.argument<String>("certs")
        if (certs == "") {
            return result.error("required_argument", "certs is a required argument", null)
        }

        return try {
            val json = mobileNebula.MobileNebula.parseCerts(certs)
            result.success(json)
        } catch (err: Exception) {
            result.error("unhandled_error", err.message, null)
        }
    }

    private fun nebulaGenerateKeyPair(result: MethodChannel.Result) {
        val kp = mobileNebula.MobileNebula.generateKeyPair()
        return result.success(kp)
    }

    private fun nebulaRenderConfig(call: MethodCall, result: MethodChannel.Result) {
        val config = call.arguments as String
        val yaml = mobileNebula.MobileNebula.renderConfig(config, "<hidden>")
        return result.success(yaml)
    }

    private fun listSites(result: MethodChannel.Result) {
        sites!!.refreshSites(activeSiteId)
        val sites = sites!!.getSites()
        val gson = Gson()
        val json = gson.toJson(sites)
        result.success(json)
    }

    private fun deleteSite(call: MethodCall, result: MethodChannel.Result) {
        val id = call.arguments as String
        if (activeSiteId == id) {
            stopSite()
        }
        sites!!.deleteSite(id)
        result.success(null)
    }

    private fun saveSite(call: MethodCall, result: MethodChannel.Result) {
        val site: IncomingSite
        try {
            val gson = Gson()
            site = gson.fromJson(call.arguments as String, IncomingSite::class.java)
            site.save(context)

        } catch (err: Exception) {
            //TODO: is toString the best or .message?
            return result.error("failure", err.toString(), null)
        }

        val siteDir = context.filesDir.resolve("sites").resolve(site.id)
        try {
            // Try to render a full site, if this fails the config was bad somehow
            Site(siteDir)
        } catch (err: Exception) {
            siteDir.deleteRecursively()
            return result.error("failure", "Site config was incomplete, please review and try again", null)
        }

        result.success(null)
    }

    private fun startSite(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id == "") {
            return result.error("required_argument", "id is a required argument", null)
        }

        var siteContainer: SiteContainer = sites!!.getSite(id!!) ?: return result.error("unknown_site", "No site with that id exists", null)

        siteContainer.site.connected = true
        siteContainer.site.status = "Initializing..."

        val intent = VpnService.prepare(this)
        if (intent != null) {
            //TODO: ensure this boots the correct bit, I bet it doesn't and we need to go back to the active symlink
            intent.putExtra("path", siteContainer.site.path)
            intent.putExtra("id", siteContainer.site.id)
            startActivityForResult(intent, VPN_START_CODE)

        } else {
            val intent = Intent(this, NebulaVpnService::class.java)
            intent.putExtra("path", siteContainer.site.path)
            intent.putExtra("id", siteContainer.site.id)
            onActivityResult(VPN_START_CODE, Activity.RESULT_OK, intent)
        }

        result.success(null)
    }

    private fun stopSite() {
        val intent = Intent(this, NebulaVpnService::class.java)
        intent.putExtra("COMMAND", "STOP")

        //This is odd but stopService goes nowhere in my tests and this is correct
        // according to the official example https://android.googlesource.com/platform/development/+/master/samples/ToyVpn/src/com/example/android/toyvpn/ToyVpnClient.java#116
        startService(intent)
        //TODO: why doesn't this work!?!?
//        if (serviceIntent != null) {
//            Log.e(TAG, "stopping ${serviceIntent.toString()}")
//            stopService(serviceIntent)
//        }
    }

    private fun activeListHostmap(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id == "") {
            return result.error("required_argument", "id is a required argument", null)
        }

        if (outMessenger == null || activeSiteId == null || activeSiteId != id) {
            return result.success(null)
        }

        var msg = Message.obtain()
        msg.what = NebulaVpnService.MSG_LIST_HOSTMAP
        msg.replyTo = Messenger(object: Handler() {
            override fun handleMessage(msg: Message) {
                result.success(msg.data.getString("data"))
            }
        })
        outMessenger?.send(msg)
    }

    private fun activeListPendingHostmap(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id == "") {
            return result.error("required_argument", "id is a required argument", null)
        }

        if (outMessenger == null || activeSiteId == null || activeSiteId != id) {
            return result.success(null)
        }

        var msg = Message.obtain()
        msg.what = NebulaVpnService.MSG_LIST_PENDING_HOSTMAP
        msg.replyTo = Messenger(object: Handler() {
            override fun handleMessage(msg: Message) {
                result.success(msg.data.getString("data"))
            }
        })
        outMessenger?.send(msg)
    }

    private fun activeGetHostInfo(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id == "") {
            return result.error("required_argument", "id is a required argument", null)
        }

        val vpnIp = call.argument<String>("vpnIp")
        if (vpnIp == "") {
            return result.error("required_argument", "vpnIp is a required argument", null)
        }

        val pending = call.argument<Boolean>("pending") ?: false
        
        if (outMessenger == null || activeSiteId == null || activeSiteId != id) {
            return result.success(null)
        }

        var msg = Message.obtain()
        msg.what = NebulaVpnService.MSG_GET_HOSTINFO
        msg.data.putString("vpnIp", vpnIp)
        msg.data.putBoolean("pending", pending)
        msg.replyTo = Messenger(object: Handler() {
            override fun handleMessage(msg: Message) {
                result.success(msg.data.getString("data"))
            }
        })
        outMessenger?.send(msg)
    }

    private fun activeSetRemoteForTunnel(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id == "") {
            return result.error("required_argument", "id is a required argument", null)
        }

        val vpnIp = call.argument<String>("vpnIp")
        if (vpnIp == "") {
            return result.error("required_argument", "vpnIp is a required argument", null)
        }

        val addr = call.argument<String>("addr")
        if (vpnIp == "") {
            return result.error("required_argument", "addr is a required argument", null)
        }

        if (outMessenger == null || activeSiteId == null || activeSiteId != id) {
            return result.success(null)
        }

        var msg = Message.obtain()
        msg.what = NebulaVpnService.MSG_SET_REMOTE_FOR_TUNNEL
        msg.data.putString("vpnIp", vpnIp)
        msg.data.putString("addr", addr)
        msg.replyTo = Messenger(object: Handler() {
            override fun handleMessage(msg: Message) {
                result.success(msg.data.getString("data"))
            }
        })
        outMessenger?.send(msg)
    }
    
    private fun activeCloseTunnel(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id == "") {
            return result.error("required_argument", "id is a required argument", null)
        }

        val vpnIp = call.argument<String>("vpnIp")
        if (vpnIp == "") {
            return result.error("required_argument", "vpnIp is a required argument", null)
        }

        if (outMessenger == null || activeSiteId == null || activeSiteId != id) {
            return result.success(null)
        }

        var msg = Message.obtain()
        msg.what = NebulaVpnService.MSG_CLOSE_TUNNEL
        msg.data.putString("vpnIp", vpnIp)
        msg.replyTo = Messenger(object: Handler() {
            override fun handleMessage(msg: Message) {
                result.success(msg.data.getBoolean("data"))
            }
        })
        outMessenger?.send(msg)
    }

    private fun androidPermissions(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            permResult = result
            return startActivityForResult(intent, VPN_PERMISSIONS_CODE)
        }

        // We already have the permission
        result.success(null)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // This is where activity results come back to us (startActivityForResult)
        if (requestCode == VPN_PERMISSIONS_CODE && permResult != null) {
            // We are processing a response for vpn permissions and the UI is waiting for feedback
            //TODO: unlikely we ever register multiple attempts but this could be a trouble spot if we did
            val result = permResult!!
            permResult = null
            if (resultCode == Activity.RESULT_OK) {
                return result.success(null)
            }

            return result.error("denied", "User did not grant permission", null)

        } else if (requestCode == VPN_START_CODE) {
            // We are processing a response for permissions while starting the VPN (or reusing code in the event we already have perms)
            startService(data)
            if (outMessenger == null) {
                bindService(data, connection, 0)
            }
            return
        }

        // The file picker needs us to super
        super.onActivityResult(requestCode, resultCode, data)
    }

    /** Defines callbacks for service binding, passed to bindService()  */
    val connection = object : ServiceConnection {
        override fun onServiceConnected(className: ComponentName, service: IBinder) {
            outMessenger = Messenger(service)
            // We want to monitor the service for as long as we are connected to it.
            try {
                val msg = Message.obtain(null, NebulaVpnService.MSG_REGISTER_CLIENT)
                msg.replyTo = inMessenger
                outMessenger?.send(msg)

            } catch (e: RemoteException) {
                // In this case the service has crashed before we could even
                // do anything with it; we can count on soon being
                // disconnected (and then reconnected if it can be restarted)
                // so there is no need to do anything here.
                //TODO:
            }

            val msg = Message.obtain(null, NebulaVpnService.MSG_IS_RUNNING)
            outMessenger?.send(msg)
        }

        override fun onServiceDisconnected(arg0: ComponentName) {
            outMessenger = null
            if (activeSiteId != null) {
                //TODO: this indicates the service died, notify that it is disconnected
            }
            activeSiteId = null
        }
    }

    // Handle and route messages coming from the vpn service
    inner class IncomingHandler: Handler() {
        override fun handleMessage(msg: Message) {
            val id = msg.data.getString("id")

            //TODO: If the elvis hits then we had a deleted site running, which shouldn't happen
            val site = sites!!.getSite(id!!) ?: return

            when (msg.what) {
                NebulaVpnService.MSG_IS_RUNNING -> isRunning(site, msg)
                NebulaVpnService.MSG_EXIT -> serviceExited(site, msg)
                else -> super.handleMessage(msg)
            }
        }

        private fun isRunning(site: SiteContainer, msg: Message) {
            var status = "Disconnected"
            var connected = false
            
            if (msg.arg1 == 1) {
                status = "Connected"
                connected = true
            }

            activeSiteId = site.site.id
            site.updater.setState(connected, status)
        }

        private fun serviceExited(site: SiteContainer, msg: Message) {
            activeSiteId = null
            site.updater.setState(false, "Disconnected", msg.data.getString("error"))
        }
    }
}
