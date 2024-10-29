package net.defined.mobile_nebula

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.*
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.work.*
import com.google.gson.Gson
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File
import java.util.concurrent.TimeUnit

const val TAG = "nebula"
const val VPN_START_CODE = 0x10
const val CHANNEL = "net.defined.mobileNebula/NebulaVpnService"
const val UPDATE_WORKER = "dnUpdater"

class MainActivity: FlutterActivity() {
    private var ui: MethodChannel? = null

    private var inMessenger: Messenger? = Messenger(IncomingHandler())
    private var outMessenger: Messenger? = null

    private var apiClient: APIClient? = null
    private var sites: Sites? = null

    // When starting a site we may need to request VPN permissions. These variables help us
    // maintain state while waiting for a permission result.
    private var startResult: MethodChannel.Result? = null
    private var startingSiteContainer: SiteContainer? = null

    private var activeSiteId: String? = null

    private val workManager = WorkManager.getInstance(application)
    private val refreshReceiver: BroadcastReceiver = RefreshReceiver()

    companion object {
        const val ACTION_REFRESH_SITES = "net.defined.mobileNebula.REFRESH_SITES"

        private var appContext: Context? = null
        fun getContext(): Context? { return appContext }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        appContext = context
        //TODO: Initializing in the constructor leads to a context lacking info we need, figure out the right way to do this
        sites = Sites(flutterEngine)

        GeneratedPluginRegistrant.registerWith(flutterEngine)

        ui = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        ui!!.setMethodCallHandler { call, result ->
            when(call.method) {
                "android.registerActiveSite" -> registerActiveSite(result)
                "android.deviceHasCamera" -> deviceHasCamera(result)

                "nebula.parseCerts" -> nebulaParseCerts(call, result)
                "nebula.generateKeyPair" -> nebulaGenerateKeyPair(result)
                "nebula.renderConfig" -> nebulaRenderConfig(call, result)
                "nebula.verifyCertAndKey" -> nebulaVerifyCertAndKey(call, result)

                "dn.enroll" -> dnEnroll(call, result)

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

                "debug.clearKeys" -> {
                    EncFile(context).resetMasterKey()
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        apiClient = APIClient(context)

        ContextCompat.registerReceiver(context, refreshReceiver, IntentFilter(ACTION_REFRESH_SITES), RECEIVER_NOT_EXPORTED)

        enqueueDNUpdater()
    }

    override fun onDestroy() {
        super.onDestroy()

        unregisterReceiver(refreshReceiver)
    }

    private fun enqueueDNUpdater() {
        val workRequest = PeriodicWorkRequestBuilder<DNUpdateWorker>(15, TimeUnit.MINUTES).build()
        workManager.enqueueUniquePeriodicWork(
                UPDATE_WORKER,
                ExistingPeriodicWorkPolicy.KEEP,
                workRequest)
    }

    // This is called by the UI _after_ it has finished rendering the site list to avoid a race condition with detecting
    // the current active site and attaching site specific event channels in the event the UI app was quit
    private fun registerActiveSite(result: MethodChannel.Result) {
        // Bind against our service to detect which site is running on app boot
        val intent = Intent(this, NebulaVpnService::class.java)
        bindService(intent, connection, 0)
        result.success(null)
    }

    private fun deviceHasCamera(result: MethodChannel.Result) {
        result.success(context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY))
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

    private fun nebulaVerifyCertAndKey(call: MethodCall, result: MethodChannel.Result) {
        val cert = call.argument<String>("cert")
        if (cert == "") {
            return result.error("required_argument", "cert is a required argument", null)
        }

        val key = call.argument<String>("key")
        if (key == "") {
            return result.error("required_argument", "key is a required argument", null)
        }

        return try {
            val json = mobileNebula.MobileNebula.verifyCertAndKey(cert, key)
            result.success(json)
        } catch (err: Exception) {
            result.error("unhandled_error", err.message, null)
        }
    }

    private fun dnEnroll(call: MethodCall, result: MethodChannel.Result) {
        val code = call.arguments as String
        if (code == "") {
            return result.error("required_argument", "code is a required argument", null)
        }

        val site: IncomingSite
        val siteDir: File
        try {
            site = apiClient!!.enroll(code)
            siteDir = site.save(context)
        } catch (err: Exception) {
            return result.error("unhandled_error", err.message, null)
        }

        if (!validateOrDeleteSite(siteDir)) {
            return result.error("failure", "Enrollment failed due to invalid config", null)
        }

        result.success(null)
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
        val siteDir: File
        try {
            val gson = Gson()
            site = gson.fromJson(call.arguments as String, IncomingSite::class.java)
            siteDir = site.save(context)
        } catch (err: Exception) {
            //TODO: is toString the best or .message?
            return result.error("failure", err.toString(), null)
        }

        if (!validateOrDeleteSite(siteDir)) {
            return result.error("failure", "Site config was incomplete, please review and try again", null)
        }

        sites?.refreshSites()

        result.success(null)
    }

    private fun validateOrDeleteSite(siteDir: File): Boolean {
        try {
            // Try to render a full site, if this fails the config was bad somehow
            Site(context, siteDir)
        } catch(err: java.io.FileNotFoundException) {
            Log.e(TAG, "Site not found at $siteDir")
            return false
        } catch(err: Exception) {
            Log.e(TAG, "Deleting site at $siteDir due to error: $err")
            siteDir.deleteRecursively()
            return false
        }
        return true
    }

    private fun startSite(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id == "") {
            return result.error("required_argument", "id is a required argument", null)
        }

        startingSiteContainer = sites!!.getSite(id!!) ?: return result.error("unknown_site", "No site with that id exists", null)
        startingSiteContainer!!.updater.setState(true, "Initializing...")

        startResult = result
        val intent = VpnService.prepare(this)
        if (intent != null) {
            startActivityForResult(intent, VPN_START_CODE)
        } else {
            onActivityResult(VPN_START_CODE, Activity.RESULT_OK, null)
        }
    }

    private fun stopSite() {
        val intent = Intent(this, NebulaVpnService::class.java).apply {
            action = NebulaVpnService.ACTION_STOP
        }

        // We can't stopService because we have to close the fd first. The service will call stopSelf when ready.
        // See the official example: https://android.googlesource.com/platform/development/+/master/samples/ToyVpn/src/com/example/android/toyvpn/ToyVpnClient.java#116
        startService(intent)
    }

    private fun activeListHostmap(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id == "") {
            return result.error("required_argument", "id is a required argument", null)
        }

        if (outMessenger == null || activeSiteId == null || activeSiteId != id) {
            return result.success(null)
        }

        val msg = Message.obtain()
        msg.what = NebulaVpnService.MSG_LIST_HOSTMAP
        msg.replyTo = Messenger(object: Handler(Looper.getMainLooper()) {
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

        val msg = Message.obtain()
        msg.what = NebulaVpnService.MSG_LIST_PENDING_HOSTMAP
        msg.replyTo = Messenger(object: Handler(Looper.getMainLooper()) {
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

        val msg = Message.obtain()
        msg.what = NebulaVpnService.MSG_GET_HOSTINFO
        msg.data.putString("vpnIp", vpnIp)
        msg.data.putBoolean("pending", pending)
        msg.replyTo = Messenger(object: Handler(Looper.getMainLooper()) {
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
        if (addr == "") {
            return result.error("required_argument", "addr is a required argument", null)
        }

        if (outMessenger == null || activeSiteId == null || activeSiteId != id) {
            return result.success(null)
        }

        val msg = Message.obtain()
        msg.what = NebulaVpnService.MSG_SET_REMOTE_FOR_TUNNEL
        msg.data.putString("vpnIp", vpnIp)
        msg.data.putString("addr", addr)
        msg.replyTo = Messenger(object: Handler(Looper.getMainLooper()) {
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

        val msg = Message.obtain()
        msg.what = NebulaVpnService.MSG_CLOSE_TUNNEL
        msg.data.putString("vpnIp", vpnIp)
        msg.replyTo = Messenger(object: Handler(Looper.getMainLooper()) {
            override fun handleMessage(msg: Message) {
                result.success(msg.data.getBoolean("data"))
            }
        })
        outMessenger?.send(msg)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // This is where activity results come back to us (startActivityForResult)
        if (requestCode == VPN_START_CODE) {
            // If we are processing a result for VPN permissions and don't get them, let the UI know
            val result = startResult!!
            val siteContainer = startingSiteContainer!!
            startResult = null
            startingSiteContainer = null
            if (resultCode != Activity.RESULT_OK) {
                // The user did not grant permissions
                siteContainer.updater.setState(false, "Disconnected")
                return result.error("permissions", "Please grant VPN permissions to the app when requested. (If another VPN is running, please disable it now.)", null)
            }

            // Start the VPN service
            val intent = Intent(this, NebulaVpnService::class.java).apply {
                putExtra("path", siteContainer.site.path)
                putExtra("id", siteContainer.site.id)
            }
            startService(intent)
            if (outMessenger == null) {
                bindService(intent, connection, 0)
            }

            return result.success(null)
        }

        // The file picker needs us to super
        super.onActivityResult(requestCode, resultCode, data)
    }


    /** Defines callbacks for service binding, passed to bindService()  */
    private val connection = object : ServiceConnection {
        override fun onServiceConnected(className: ComponentName, service: IBinder) {
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
                //TODO:
            }

            val msg = Message.obtain(null, NebulaVpnService.MSG_IS_RUNNING)
            outMessenger!!.send(msg)
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
    inner class IncomingHandler: Handler(Looper.getMainLooper()) {
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
            unbindVpnService()
        }
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

    inner class RefreshReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent?) {
            if (intent?.action != ACTION_REFRESH_SITES) return
            if (sites == null) return

            Log.d(TAG, "Refreshing sites in MainActivity")

            sites?.refreshSites(activeSiteId)
            ui?.invokeMethod("refreshSites", null)
        }
    }

}
