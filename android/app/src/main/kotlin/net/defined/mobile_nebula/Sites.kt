package net.defined.mobile_nebula

import android.content.Context
import android.util.Log
import com.google.gson.Gson
import com.google.gson.annotations.Expose
import com.google.gson.annotations.SerializedName
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import java.io.File
import kotlin.collections.HashMap

data class SiteContainer(
    val site: Site,
    val updater: SiteUpdater
)

class Sites(private var engine: FlutterEngine) {
    private var sites: HashMap<String, SiteContainer> = HashMap()

    init {
        refreshSites()
    }

    fun refreshSites(activeSite: String? = null) {
        val context = MainActivity.getContext()!!
        val sitesDir = context.filesDir.resolve("sites")
        if (!sitesDir.isDirectory) {
            sitesDir.delete()
            sitesDir.mkdir()
        }

        sites = HashMap()
        sitesDir.listFiles().forEach { siteDir ->
            try {
                val site = Site(siteDir)

                // Make sure we can load the private key
                site.getKey(context)

                val updater = SiteUpdater(site, engine)
                if (site.id == activeSite) {
                    updater.setState(true, "Connected")
                }

                this.sites[site.id] = SiteContainer(site, updater)

            } catch (err: Exception) {
                siteDir.deleteRecursively()
                Log.e(TAG, "Deleting non conforming site ${siteDir.absolutePath}", err)
            }
        }
    }

    fun getSites(): Map<String, Site>  {
        return sites.mapValues { it.value.site }
    }

    fun deleteSite(id: String) {
        sites.remove(id)
        val siteDir = MainActivity.getContext()!!.filesDir.resolve("sites").resolve(id)
        siteDir.deleteRecursively()
        //TODO: make sure you stop the vpn
        //TODO: make sure you relink the active site if this is the active site
    }
    
    fun getSite(id: String): SiteContainer? {
        return sites[id]
    }
}

class SiteUpdater(private var site: Site, engine: FlutterEngine): EventChannel.StreamHandler {
    // eventSink is how we send info back up to flutter
    private var eventChannel: EventChannel = EventChannel(engine.dartExecutor.binaryMessenger, "net.defined.nebula/${site.id}")
    private var eventSink: EventChannel.EventSink? = null
    
    fun setState(connected: Boolean, status: String, err: String? = null) {
        site.connected = connected
        site.status = status
        val d = mapOf("connected" to site.connected, "status" to site.status)
        if (err != null) {
            eventSink?.error("", err, d)
        } else {
            eventSink?.success(d)
        }
    }

    init {
        eventChannel.setStreamHandler(this)
    }

    // Methods for EventChannel.StreamHandler
    override fun onListen(p0: Any?, p1: EventChannel.EventSink?) {
        eventSink = p1
    }

    override fun onCancel(p0: Any?) {
        eventSink = null
    }

}

data class CertificateInfo(
    @SerializedName("Cert") val cert: Certificate,
    @SerializedName("RawCert") val rawCert: String,
    @SerializedName("Validity") val validity: CertificateValidity
)

data class Certificate(
    val fingerprint: String,
    val signature: String,
    val details: CertificateDetails
)

data class CertificateDetails(
    val name: String,
    val notBefore: String,
    val notAfter: String,
    val publicKey: String,
    val groups: List<String>,
    val ips: List<String>,
    val subnets: List<String>,
    val isCa: Boolean,
    val issuer: String
)

data class CertificateValidity(
    @SerializedName("Valid") val valid: Boolean,
    @SerializedName("Reason") val reason: String
)

class Site {
    val name: String
    val id: String
    val staticHostmap: HashMap<String, StaticHosts>
    val unsafeRoutes: List<UnsafeRoute>
    val dnsResolvers: List<String>
    var cert: CertificateInfo? = null
    var ca: Array<CertificateInfo>
    val lhDuration: Int
    val port: Int
    val mtu: Int
    val cipher: String
    val sortKey: Int
    var logVerbosity: String
    var connected: Boolean?
    var status: String?
    val logFile: String?
    var errors: ArrayList<String> = ArrayList()
    
    // Path to this site on disk
    @Expose(serialize = false)
    val path: String

    // Strong representation of the site config
    @Expose(serialize = false)
    val config: String
    
    constructor(siteDir: File) {
        val gson = Gson()
        config = siteDir.resolve("config.json").readText()
        val incomingSite = gson.fromJson(config, IncomingSite::class.java)

        path = siteDir.absolutePath
        name = incomingSite.name
        id = incomingSite.id
        staticHostmap = incomingSite.staticHostmap
        unsafeRoutes = incomingSite.unsafeRoutes ?: ArrayList()
        dnsResolvers = incomingSite.dnsResolvers ?: ArrayList()
        lhDuration = incomingSite.lhDuration
        port = incomingSite.port
        mtu = incomingSite.mtu ?: 1300
        cipher = incomingSite.cipher
        sortKey = incomingSite.sortKey ?: 0
        logFile = siteDir.resolve("log").absolutePath
        logVerbosity = incomingSite.logVerbosity ?: "info"

        connected = false
        status = "Disconnected"

        try {
            val rawDetails = mobileNebula.MobileNebula.parseCerts(incomingSite.cert)
            val certs = gson.fromJson(rawDetails, Array<CertificateInfo>::class.java)
            if (certs.isEmpty()) {
                throw IllegalArgumentException("No certificate found")
            }
            cert = certs[0]
            if (!cert!!.validity.valid) {
                errors.add("Certificate is invalid: ${cert!!.validity.reason}")
            }

        } catch (err: Exception) {
            errors.add("Error while loading certificate: ${err.message}")
        }

        try {
            val rawCa = mobileNebula.MobileNebula.parseCerts(incomingSite.ca)
            ca = gson.fromJson(rawCa, Array<CertificateInfo>::class.java)
            var hasErrors = false
            ca.forEach {
                if (!it.validity.valid) {
                    hasErrors = true
                }
            }

            if (hasErrors) {
                errors.add("There are issues with 1 or more ca certificates")
            }

        } catch (err: Exception) {
            ca = arrayOf()
            errors.add("Error while loading certificate authorities: ${err.message}")
        }

        if (errors.isEmpty()) {
            try {
                mobileNebula.MobileNebula.testConfig(config, getKey(MainActivity.getContext()!!))
            } catch (err: Exception) {
                errors.add("Config test error: ${err.message}")
            }
        }
    }

    fun getKey(context: Context): String? {
        val f = EncFile(context).openRead(File(path).resolve("key"))
        val k = f.readText()
        f.close()
        return k
    }
}

data class StaticHosts(
    val lighthouse: Boolean,
    val destinations: List<String>
)

data class UnsafeRoute(
    val route: String,
    val via: String,
    val mtu: Int?
)

class IncomingSite(
    val name: String,
    val id: String,
    val staticHostmap: HashMap<String, StaticHosts>,
    val unsafeRoutes: List<UnsafeRoute>?,
    val dnsResolvers: List<String>?,
    val cert: String,
    val ca: String,
    val lhDuration: Int,
    val port: Int,
    val mtu: Int?,
    val cipher: String,
    val sortKey: Int?,
    var logVerbosity: String?,
    @Expose(serialize = false)
    var key: String?
) {

    fun save(context: Context) {
        val siteDir = context.filesDir.resolve("sites").resolve(id)
        if (!siteDir.exists()) {
            siteDir.mkdir()
        }

        if (key != null) {
            val f = EncFile(context).openWrite(siteDir.resolve("key"))
            f.use { it.write(key) }
            f.close()
        }

        key = null
        val gson = Gson()
        val confFile = siteDir.resolve("config.json")
        confFile.writeText(gson.toJson(this))
    }
}
