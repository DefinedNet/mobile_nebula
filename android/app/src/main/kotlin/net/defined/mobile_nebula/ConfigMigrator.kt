package net.defined.mobile_nebula

import android.content.Context
import java.io.File

object ConfigMigrator {
    /**
     * Brings a site config up to date and writes it back to disk if anything changed.
     *
     * The migrations themselves all live in Go. This knows nothing about individual versions, it
     * only supplies the private key that Go can't reach and handles the file, so adding a
     * migration should not need a change here.
     */
    fun migrate(context: Context, siteDir: File, configJson: String): String {
        // Only the legacy format needs the key, so don't pay to decrypt it on every site load
        val key = if (mobileNebula.MobileNebula.migrationNeedsKey(configJson)) {
            try {
                val f = EncFile(context).openRead(siteDir.resolve("key"))
                val k = f.readText()
                f.close()
                k
            } catch (_: Exception) { "" }
        } else {
            ""
        }

        val migrated = mobileNebula.MobileNebula.migrateConfig(configJson, key)

        // Go hands back the input verbatim when there is nothing to do
        if (migrated == configJson) {
            return configJson
        }

        siteDir.resolve("config.json").writeText(migrated)
        return migrated
    }
}
