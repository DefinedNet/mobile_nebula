package net.defined.mobile_nebula

import android.content.Context
import android.util.Log
import com.google.gson.Gson
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
    private var containers: HashMap<String, SiteContainer> = HashMap()

    init {
        refreshSites()
    }

    fun refreshSites(activeSite: String? = null) {
        val context = MainActivity.getContext()!!

        val sites = SiteList(context)
        val containers: HashMap<String, SiteContainer> = HashMap()
        sites.getSites().values.forEach { site ->
            // Don't create a new SiteUpdater or we will lose subscribers
            var updater = this.containers[site.id]?.updater
            if (updater != null) {
                updater.setSite(site)
            } else {
                updater = SiteUpdater(site, engine)
            }

            if (site.id == activeSite) {
                updater.setState(true, "Connected")
            }

            containers[site.id] = SiteContainer(site, updater)
        }
        this.containers = containers
    }

    fun getSites(): Map<String, Site>  {
        return containers.mapValues { it.value.site }
    }

    fun deleteSite(id: String) {
        val context = MainActivity.getContext()!!
        val site = containers[id]!!.site

        val baseDir = if(site.managed) context.noBackupFilesDir else context.filesDir
        val siteDir = baseDir.resolve("sites").resolve(id)
        siteDir.deleteRecursively()
        refreshSites()
        //TODO: make sure you stop the vpn
        //TODO: make sure you relink the active site if this is the active site
    }

    fun getSite(id: String): SiteContainer? {
        return containers[id]
    }
}

class SiteList(context: Context) {
    private var sites: Map<String, Site>

    init {
        val nebulaSites = getSites(context, context.filesDir)
        val dnSites = getSites(context, context.noBackupFilesDir)

        // In case of a conflict, dnSites will take precedence.
        sites = nebulaSites + dnSites
    }

    fun getSites(): Map<String, Site>  {
        return sites
    }

    companion object {
        fun getSites(context: Context, directory: File): HashMap<String, Site> {
            val sites = HashMap<String, Site>()

            val sitesDir = directory.resolve("sites")

            if (!sitesDir.isDirectory) {
                sitesDir.delete()
                sitesDir.mkdir()
            }

            sitesDir.listFiles()?.forEach { siteDir ->
                try {
                    val site = Site(context, siteDir)

                    // Make sure we can load the private key
                    site.getKey(context)

                    // Make sure we can load the DN credentials if managed
                    if (site.managed) {
                        site.getDNCredentials(context)
                    }

                    sites[site.id] = site
                } catch (err: Exception) {
                    siteDir.deleteRecursively()
                    Log.e(TAG, "Deleting non conforming site ${siteDir.absolutePath}", err)
                }
            }

            return sites
        }
    }
}

class SiteUpdater(private var site: Site, engine: FlutterEngine): EventChannel.StreamHandler {
    private val gson = Gson()
    // eventSink is how we send info back up to flutter
    private var eventChannel: EventChannel = EventChannel(engine.dartExecutor.binaryMessenger, "net.defined.nebula/${site.id}")
    private var eventSink: EventChannel.EventSink? = null

    fun setSite(site: Site) {
        this.site = site
    }

    fun setState(connected: Boolean, status: String, err: String? = null) {
        site.connected = connected
        site.status = status
        if (err != null) {
            eventSink?.error("", err, gson.toJson(site))
        } else {
            eventSink?.success(gson.toJson(site))
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

data class DNCredentials(
    val hostID: String,
    val privateKey: String,
    val counter: Int,
    val trustedKeys: String,
    var invalid: Boolean,
) {
    fun save(context: Context, siteDir: File) {
        val jsonCreds = Gson().toJson(this)

        val credsFile = siteDir.resolve("dnCredentials")
        credsFile.delete()

        EncFile(context).openWrite(credsFile).use { it.write(jsonCreds) }
    }
}

class Site(context: Context, siteDir: File) {
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
    val logVerbosity: String
    var connected: Boolean?
    var status: String?
    val logFile: String?
    var errors: ArrayList<String> = ArrayList()
    val managed: Boolean
    // The following fields are present when managed = true
    val rawConfig: String?
    val lastManagedUpdate: String?

    // Path to this site on disk
    @Transient
    val path: String

    // Strong representation of the site config
    @Transient
    val config: String

     init {
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
        rawConfig = incomingSite.rawConfig
        managed = incomingSite.managed ?: false
        lastManagedUpdate = incomingSite.lastManagedUpdate

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

            if (hasErrors && !managed) {
                errors.add("There are issues with 1 or more ca certificates")
            }

        } catch (err: Exception) {
            ca = arrayOf()
            errors.add("Error while loading certificate authorities: ${err.message}")
        }

        if (managed && getDNCredentials(context).invalid) {
            errors.add("Unable to fetch updates - please re-enroll the device")
        }

        if (errors.isEmpty()) {
            try {
                mobileNebula.MobileNebula.testConfig(config, getKey(MainActivity.getContext()!!))
            } catch (err: Exception) {
                errors.add("Config test error: ${err.message}")
            }
        }
    }

    fun getKey(context: Context): String {
        val f = EncFile(context).openRead(File(path).resolve("key"))
        val k = f.readText()
        f.close()
        return k
    }

    fun getDNCredentials(context: Context): DNCredentials {
        val filepath = File(path).resolve("dnCredentials")
        val f = EncFile(context).openRead(filepath)
        val cfg = f.use { it.readText() }
        return Gson().fromJson(cfg, DNCredentials::class.java)
    }

    fun invalidateDNCredentials(context: Context) {
        val creds = getDNCredentials(context)
        creds.invalid = true
        creds.save(context, File(path))
    }

    fun validateDNCredentials(context: Context) {
        val creds = getDNCredentials(context)
        creds.invalid = false
        creds.save(context, File(path))
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
    val logVerbosity: String?,
    var key: String?,
    val managed: Boolean?,
    // The following fields are present when managed = true
    val lastManagedUpdate: String?,
    val rawConfig: String?,
    var dnCredentials: DNCredentials?,
) {
    fun save(context: Context): File {
        // Don't allow backups of DN-managed sites
        val baseDir = if(managed == true) context.noBackupFilesDir else context.filesDir
        val siteDir = baseDir.resolve("sites").resolve(id)
        if (!siteDir.exists()) {
            siteDir.mkdir()
        }

        if (key != null) {
            val keyFile = siteDir.resolve("key")
            keyFile.delete()
            val encFile = EncFile(context).openWrite(keyFile)
            encFile.use { it.write(key) }
            encFile.close()
        }
        key = null

        dnCredentials?.save(context, siteDir)
        dnCredentials = null

        val confFile = siteDir.resolve("config.json")
        confFile.writeText(Gson().toJson(this))

        return siteDir
    }
}
