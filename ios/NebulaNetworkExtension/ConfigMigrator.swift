import Foundation
import MobileNebula

protocol ConfigMigration {
  func migrate(_ site: IncomingSite, errors: inout [String]) -> IncomingSite
}

struct FirewallMigration: ConfigMigration {
  func migrate(_ site: IncomingSite, errors: inout [String]) -> IncomingSite {
    var site = site
    if let rawConfig = site.rawConfig {
      // Managed site: parse the actual firewall rules from the rawConfig YAML
      var parseErr: NSError?
      let rulesJson = MobileNebulaParseFirewallRules(rawConfig, &parseErr)
      if parseErr == nil, let data = rulesJson.data(using: .utf8),
        let parsed = try? JSONDecoder().decode(ParsedFirewallRules.self, from: data)
      {
        site.inboundRules = parsed.inboundRules ?? []
        site.outboundRules = parsed.outboundRules ?? []
      } else {
        errors.append(
          "Failed to parse firewall rules from config: \(parseErr?.localizedDescription ?? "unknown")"
        )
      }
    } else {
      // Unmanaged site: apply default allow-all outbound
      site.inboundRules = []
      site.outboundRules = [FirewallRule(protocol: "any", startPort: 0, endPort: 0, host: "any")]
    }
    return site
  }
}

enum ConfigMigrator {
  private static let migrations: [ConfigMigration] = [FirewallMigration()]

  static func migrate(_ incomingSite: IncomingSite, errors: inout [String]) -> IncomingSite {
    var site = incomingSite
    let startVersion = site.configVersion ?? 0

    for i in startVersion..<migrations.count {
      site = migrations[i].migrate(site, errors: &errors)
      site.configVersion = i + 1
    }

    if (site.configVersion ?? 0) != startVersion {
      if let configPath = try? SiteList.getSiteConfigFile(id: site.id, createDir: false),
        let configData = try? JSONEncoder().encode(site)
      {
        try? configData.write(to: configPath)
      }
    }

    return site
  }
}
