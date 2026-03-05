package net.defined.mobile_nebula

import android.content.Context
import java.io.File

object ConfigMigrator {
    /**
     * Migrates a site's config to the latest version if needed.
     * Writes the migrated config back to disk and returns the updated JSON.
     */
    fun migrate(context: Context, siteDir: File, configJson: String): String {
        val configMap: Map<String, Any?> =
            com.google.gson.Gson().fromJson(configJson, object : com.google.gson.reflect.TypeToken<Map<String, Any?>>() {}.type)
        var version = (configMap["configVersion"] as? Number)?.toInt() ?: 0
        var result = configJson

        if (version < 1) {
            result = migrateToV1(context, siteDir, result)
            version = 1
        }

        // Future migrations go here

        return result
    }

    /** Migrates from v0 (old decomposed format) to v1 (rawConfig format). */
    private fun migrateToV1(context: Context, siteDir: File, configJson: String): String {
        val key = try {
            val f = EncFile(context).openRead(siteDir.resolve("key"))
            val k = f.readText()
            f.close()
            k
        } catch (_: Exception) { "" }

        val migrated = mobileNebula.MobileNebula.migrateConfig(configJson, key)
        siteDir.resolve("config.json").writeText(migrated)
        return migrated
    }
}
