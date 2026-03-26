package net.defined.mobile_nebula

import android.content.Context
import android.util.Log
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import com.google.gson.reflect.TypeToken
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

    fun updateAll() {
        containers.values.forEach { it.updater.notifyChanged() }
    }

    fun deleteSite(id: String) {
        val context = MainActivity.getContext()!!
        val site = containers[id]!!.site

        val alwaysOnFile = context.filesDir.resolve("always-on-site")
        if (alwaysOnFile.exists() && alwaysOnFile.readText() == site.path) {
            alwaysOnFile.delete()
        }

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

    fun notifyChanged() {
        eventSink?.success(gson.toJson(site))
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
    val version: Int,
    val name: String,
    val networks: List<String>,
    val unsafeNetworks: List<String>,
    val groups: List<String>,
    val isCa: Boolean,
    val notBefore: String,
    val notAfter: String,
    val issuer: String,
    val publicKey: String,
    val curve: String,
    val fingerprint: String,
    val signature: String,
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

// UnsafeRoute is used by the VPN service to configure routing
data class UnsafeRoute(
    val route: String,
    val via: String,
    val mtu: Int?
)

/**
 * Saves a site JSON string to disk. Extracts key and dnCredentials into
 * encrypted storage, handles the always-on file, and writes the remaining
 * config to config.json. Returns the site directory.
 */
fun saveSite(context: Context, jsonString: String): File {
    val gson = Gson()
    val map: MutableMap<String, Any?> = gson.fromJson(jsonString, object : TypeToken<MutableMap<String, Any?>>() {}.type)

    val id = map["id"] as String
    val managed = map["managed"] as? Boolean ?: false
    val alwaysOn = map["alwaysOn"] as? Boolean

    // Don't allow backups of DN-managed sites
    val baseDir = if (managed) context.noBackupFilesDir else context.filesDir
    val siteDir = baseDir.resolve("sites").resolve(id)
    if (!siteDir.exists()) {
        siteDir.mkdir()
    }

    // Extract and encrypt key
    val key = map["key"] as? String
    if (key != null) {
        val keyFile = siteDir.resolve("key")
        keyFile.delete()
        val encFile = EncFile(context).openWrite(keyFile)
        encFile.use { it.write(key) }
        encFile.close()
    }
    map.remove("key")

    // Extract and encrypt dnCredentials
    val dnCredentials = map["dnCredentials"]
    if (dnCredentials != null) {
        val creds = gson.fromJson(gson.toJson(dnCredentials), DNCredentials::class.java)
        creds.save(context, siteDir)
    }
    map.remove("dnCredentials")

    // Handle always-on file
    val alwaysOnFile = context.filesDir.resolve("always-on-site")
    when (alwaysOn) {
        true -> alwaysOnFile.writeText(siteDir.absolutePath)
        false -> if (alwaysOnFile.exists() && alwaysOnFile.readText() == siteDir.absolutePath) {
            alwaysOnFile.delete()
        }
        null -> {}
    }
    map.remove("alwaysOn")

    // Stamp the current config version
    map["configVersion"] = 1

    // Write the remaining config to disk
    val confFile = siteDir.resolve("config.json")
    confFile.writeText(gson.toJson(map))

    return siteDir
}

class Site(context: Context, siteDir: File) {
    val name: String
    val id: String
    val sortKey: Int
    val managed: Boolean
    val lastManagedUpdate: String?
    val rawConfig: String  // JSON string of nebula config (no private key)
    val configVersion: Int

    // Display-only fields (parsed from rawConfig during init)
    var cert: CertificateInfo? = null
    var ca: Array<CertificateInfo>
    var connected: Boolean?
    var status: String?
    val logFile: String?
    var errors: ArrayList<String> = ArrayList()
    var excludedApps: List<String> = ArrayList()
    val alwaysOn: Boolean

    // Fields parsed from rawConfig for VPN service use
    val mtu: Int
    val unsafeRoutes: List<UnsafeRoute>
    val dnsResolvers: List<String>

    // Path to this site on disk
    @Transient
    val path: String

    // Full site JSON (passed to RenderConfig/TestConfig)
    @Transient
    val config: String

     init {
        val gson = Gson()
        val configJson = ConfigMigrator.migrate(context, siteDir, siteDir.resolve("config.json").readText())

        config = configJson

        // Parse site metadata directly from the JSON map
        val siteMap: Map<String, Any?> = gson.fromJson(configJson, object : TypeToken<Map<String, Any?>>() {}.type)

        path = siteDir.absolutePath
        name = siteMap["name"] as? String ?: ""
        id = siteMap["id"] as? String ?: ""
        sortKey = (siteMap["sortKey"] as? Number)?.toInt() ?: 0
        managed = siteMap["managed"] as? Boolean ?: false
        lastManagedUpdate = siteMap["lastManagedUpdate"] as? String
        rawConfig = siteMap["rawConfig"] as? String ?: "{}"
        configVersion = (siteMap["configVersion"] as? Number)?.toInt() ?: 1
        logFile = siteDir.resolve("log").absolutePath

        // Parse excludedApps from site config
        @Suppress("UNCHECKED_CAST")
        excludedApps = (siteMap["excludedApps"] as? List<String>) ?: emptyList()

        connected = false
        status = "Disconnected"

        val alwaysOnPath = try { context.filesDir.resolve("always-on-site").readText() } catch (_: Exception) { null }
        alwaysOn = alwaysOnPath == path

        // Parse rawConfig JSON to extract fields needed by VPN service and display
        val rawConfigMap: Map<String, Any?> = try {
            gson.fromJson(rawConfig, object : TypeToken<Map<String, Any?>>() {}.type) ?: emptyMap()
        } catch (err: Exception) {
            errors.add("Failed to parse rawConfig: ${err.message}")
            emptyMap()
        }

        // Parse mtu from rawConfig
        mtu = getConfigInt(rawConfigMap, listOf("tun", "mtu")) ?: 1300

        // Parse unsafeRoutes from rawConfig
        unsafeRoutes = try {
            val tun = rawConfigMap["tun"] as? Map<*, *>
            val routes = tun?.get("unsafe_routes") as? List<*>
            routes?.mapNotNull { r ->
                val routeMap = r as? Map<*, *> ?: return@mapNotNull null
                val route = routeMap["route"] as? String ?: return@mapNotNull null
                val via = routeMap["via"] as? String ?: return@mapNotNull null
                val routeMtu = (routeMap["mtu"] as? Number)?.toInt()
                UnsafeRoute(route, via, routeMtu)
            } ?: emptyList()
        } catch (_: Exception) { emptyList() }

        // Parse dnsResolvers from rawConfig
        dnsResolvers = try {
            val mobileNebulaConfig = rawConfigMap["mobile_nebula"] as? Map<*, *>
            val resolvers = mobileNebulaConfig?.get("dns_resolvers") as? List<*>
            resolvers?.mapNotNull { it?.toString() } ?: emptyList()
        } catch (_: Exception) { emptyList() }

        // Parse cert from rawConfig's pki.cert
        val pki = rawConfigMap["pki"] as? Map<*, *>
        val certPem = pki?.get("cert") as? String
        if (certPem != null && certPem.isNotEmpty()) {
            try {
                val rawDetails = mobileNebula.MobileNebula.parseCerts(certPem)
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
        } else {
            errors.add("Error while loading certificate: no certificate found in config")
        }

        // Parse ca from rawConfig's pki.ca
        val caPem = pki?.get("ca") as? String
        if (caPem != null && caPem.isNotEmpty()) {
            try {
                val rawCa = mobileNebula.MobileNebula.parseCerts(caPem)
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
        } else {
            ca = arrayOf()
            if (!managed) {
                errors.add("Error while loading certificate authorities: no CA found in config")
            }
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

    companion object {
        /** Navigate a nested map by a list of keys and return an Int if found. */
        fun getConfigInt(config: Map<String, Any?>, path: List<String>): Int? {
            var current: Any? = config
            for (key in path.dropLast(1)) {
                current = (current as? Map<*, *>)?.get(key) ?: return null
            }
            val value = (current as? Map<*, *>)?.get(path.last())
            return (value as? Number)?.toInt()
        }
    }
}
