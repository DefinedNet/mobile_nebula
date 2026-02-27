package net.defined.mobile_nebula

import com.google.gson.Gson
import java.io.File

fun interface ConfigMigration {
    fun migrate(site: IncomingSite, errors: MutableList<String>): IncomingSite
}

class FirewallMigration : ConfigMigration {
    override fun migrate(site: IncomingSite, errors: MutableList<String>): IncomingSite {
        val rawConfig = site.rawConfig
        if (rawConfig != null) {
            // Managed site: parse the actual firewall rules from the rawConfig YAML
            try {
                val gson = Gson()
                val rulesJson = mobileNebula.MobileNebula.parseFirewallRules(rawConfig)
                val parsedRules = gson.fromJson(rulesJson, ParsedFirewallRules::class.java)
                return site.copy(
                    inboundRules = parsedRules?.inboundRules ?: emptyList(),
                    outboundRules = parsedRules?.outboundRules ?: emptyList(),
                )
            } catch (e: Exception) {
                errors.add("Failed to parse firewall rules from config: ${e.message}")
                return site
            }
        } else {
            // Unmanaged site: apply default allow-all outbound
            return site.copy(
                inboundRules = emptyList(),
                outboundRules = listOf(FirewallRule(protocol = "any", startPort = 0, endPort = 0, host = "any")),
            )
        }
    }
}

object ConfigMigrator {
    private val migrations: List<ConfigMigration> = listOf(FirewallMigration())

    fun migrate(incomingSite: IncomingSite, siteDir: File, errors: MutableList<String>): IncomingSite {
        var site = incomingSite
        val startVersion = site.configVersion ?: 0

        for (i in startVersion until migrations.size) {
            site = migrations[i].migrate(site, errors)
            site = site.copy(configVersion = i + 1)
        }

        if ((site.configVersion ?: 0) != startVersion) {
            siteDir.resolve("config.json").writeText(Gson().toJson(site))
        }

        return site
    }
}
