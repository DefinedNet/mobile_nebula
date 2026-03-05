import MobileNebula
import NetworkExtension
import SwiftyJSON
import os.log

let log = Logger(subsystem: "net.defined.mobileNebula", category: "Site")

enum SiteError: Error {
  case nonConforming(site: [String: Any]?)
  case noCertificate
  case keyLoad
  case keySave
  case unmanagedGetCredentials
  case dnCredentialLoad
  case dnCredentialSave

  // Throw in all other cases
  case unexpected(code: Int)
}

extension SiteError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .nonConforming(let site):
      return String("Non-conforming site \(String(describing: site))")
    case .noCertificate:
      return "No certificate found"
    case .keyLoad:
      return "failed to get key from keychain"
    case .keySave:
      return "failed to store key material in keychain"
    case .unmanagedGetCredentials:
      return "Cannot get dn credentials for unmanaged site"
    case .dnCredentialLoad:
      return "failed to find dn credentials in keychain"
    case .dnCredentialSave:
      return "failed to store dn credentials in keychain"
    case .unexpected(_):
      return "An unexpected error occurred."
    }
  }
}

enum IPCResponseType: String, Codable {
  case error = "error"
  case success = "success"
}

class IPCResponse: Codable {
  var type: IPCResponseType
  //TODO: change message to data?
  var message: JSON?

  init(type: IPCResponseType, message: JSON?) {
    self.type = type
    self.message = message
  }
}

class IPCRequest: Codable {
  var command: String
  var arguments: JSON?

  init(command: String, arguments: JSON?) {
    self.command = command
    self.arguments = arguments
  }

  init(command: String) {
    self.command = command
  }
}

struct CertificateInfo: Codable {
  var cert: Certificate
  var rawCert: String
  var validity: CertificateValidity

  enum CodingKeys: String, CodingKey {
    case cert = "Cert"
    case rawCert = "RawCert"
    case validity = "Validity"
  }
}

struct Certificate: Codable {
  var version: Int
  var name: String
  var networks: [String]
  var unsafeNetworks: [String]
  var groups: [String]
  var isCa: Bool
  var notBefore: String
  var notAfter: String
  var issuer: String
  var publicKey: String
  var curve: String
  var fingerprint: String
  var signature: String

  /// An empty initializer to make error reporting easier
  init() {
    version = 0
    name = ""
    networks = ["ERROR"]
    unsafeNetworks = []
    groups = []
    notBefore = ""
    notAfter = ""
    issuer = ""
    publicKey = ""
    curve = ""
    isCa = false
    fingerprint = ""
    signature = ""
  }
}

struct CertificateValidity: Codable {
  var valid: Bool
  var reason: String

  enum CodingKeys: String, CodingKey {
    case valid = "Valid"
    case reason = "Reason"
  }
}

let statusMap: [NEVPNStatus: Bool] = [
  NEVPNStatus.invalid: false,
  NEVPNStatus.disconnected: false,
  NEVPNStatus.connecting: false,
  NEVPNStatus.connected: true,
  NEVPNStatus.reasserting: true,
  NEVPNStatus.disconnecting: true,
]

let statusString: [NEVPNStatus: String] = [
  NEVPNStatus.invalid: "Invalid configuration",
  NEVPNStatus.disconnected: "Disconnected",
  NEVPNStatus.connecting: "Connecting...",
  NEVPNStatus.connected: "Connected",
  NEVPNStatus.reasserting: "Reasserting...",
  NEVPNStatus.disconnecting: "Disconnecting...",
]

// UnsafeRoute is used by the VPN service to configure routing
class UnsafeRoute: Codable {
  var route: String
  var via: String
  var mtu: Int?

  init(route: String, via: String, mtu: Int? = nil) {
    self.route = route
    self.via = via
    self.mtu = mtu
  }
}

/// Saves a site JSON string to disk. Extracts key and dnCredentials into
/// encrypted storage and writes the remaining config to config.json.
func saveSiteToDisk(jsonString: String) throws {
  guard let jsonData = jsonString.data(using: .utf8),
    let obj = try? JSONSerialization.jsonObject(with: jsonData),
    var map = obj as? [String: Any]
  else {
    throw SiteError.nonConforming(site: nil)
  }

  guard let id = map["id"] as? String else {
    throw SiteError.nonConforming(site: map)
  }

  let managed = map["managed"] as? Bool ?? false

  // Extract and encrypt key
  if let key = map["key"] as? String {
    let keyData = key.data(using: .utf8)!
    if !KeyChain.save(key: "\(id).key", data: keyData, managed: managed) {
      throw SiteError.keySave
    }
  }
  map.removeValue(forKey: "key")

  // Extract and encrypt dnCredentials
  if let dnCreds = map["dnCredentials"] {
    let credsData = try JSONSerialization.data(withJSONObject: dnCreds)
    let creds = try JSONDecoder().decode(DNCredentials.self, from: credsData)
    if !(try creds.save(siteID: id)) {
      throw SiteError.dnCredentialSave
    }
  }
  map.removeValue(forKey: "dnCredentials")

  // Strip alwaysOn (not stored in config.json)
  map.removeValue(forKey: "alwaysOn")

  // Stamp the current config version
  map["configVersion"] = 1

  // Write the remaining config to disk
  let configPath = try SiteList.getSiteConfigFile(id: id, createDir: true)
  log.notice("Saving to \(configPath, privacy: .public)")
  let configData = try JSONSerialization.data(withJSONObject: map)
  try configData.write(to: configPath)
}

/// Saves a site to disk and optionally to the system VPN profile.
func saveSite(
  jsonString: String,
  manager: NETunnelProviderManager?,
  saveToManager: Bool = true,
  callback: @escaping ((any Error)?) -> Void
) {
  do {
    try saveSiteToDisk(jsonString: jsonString)
  } catch {
    return callback(error)
  }

  #if targetEnvironment(simulator)
    callback(nil)
  #else
    if saveToManager {
      // Parse metadata needed for manager save
      guard let data = jsonString.data(using: .utf8),
        let obj = try? JSONSerialization.jsonObject(with: data),
        let map = obj as? [String: Any]
      else {
        return callback(SiteError.nonConforming(site: nil))
      }

      let id = map["id"] as? String ?? ""
      let name = map["name"] as? String ?? ""
      let alwaysOn = map["alwaysOn"] as? Bool ?? false

      doSaveToManager(
        id: id, name: name, alwaysOn: alwaysOn, manager: manager, callback: callback)
    } else {
      callback(nil)
    }
  #endif
}

func doSaveToManager(
  id: String,
  name: String,
  alwaysOn: Bool,
  manager: NETunnelProviderManager?,
  callback: @escaping ((any Error)?) -> Void
) {
  if let manager = manager {
    // We need to refresh our settings to properly update config
    manager.loadFromPreferences { error in
      if error != nil {
        return callback(error)
      }
      finishSaveToManager(
        id: id, name: name, alwaysOn: alwaysOn, manager: manager, callback: callback)
    }
    return
  }

  finishSaveToManager(
    id: id, name: name, alwaysOn: alwaysOn, manager: NETunnelProviderManager(), callback: callback)
}

private func finishSaveToManager(
  id: String,
  name: String,
  alwaysOn: Bool,
  manager: NETunnelProviderManager,
  callback: @escaping ((any Error)?) -> Void
) {
  // Stuff our details in the protocol
  let proto =
    manager.protocolConfiguration as? NETunnelProviderProtocol ?? NETunnelProviderProtocol()
  proto.providerBundleIdentifier = "net.defined.mobileNebula.NebulaNetworkExtension"
  // WARN: If we stop setting providerConfiguration["id"] here, we'll need to use something else to match
  // managers in PacketTunnelProvider.findManager
  proto.providerConfiguration = ["id": id]
  proto.serverAddress = "Nebula"

  // Finish up the manager, this is what stores everything at the system level
  manager.protocolConfiguration = proto
  //TODO: cert name?        manager.protocolConfiguration?.username

  //TODO: This is what is shown on the vpn page. We should add more identifying details in
  manager.localizedDescription = name
  manager.isEnabled = true

  manager.isOnDemandEnabled = alwaysOn
  let rule = NEOnDemandRuleConnect()
  rule.interfaceTypeMatch = .any
  manager.onDemandRules = [rule]

  manager.saveToPreferences { error in
    return callback(error)
  }
}

// Represents a site that was pulled out of the system configuration
class Site: Encodable {
  // Core fields (stored in config.json)
  var name: String
  var id: String
  var sortKey: Int
  var managed: Bool
  var lastManagedUpdate: String?
  var rawConfig: String  // JSON string of nebula config (no private key)
  var configVersion: Int

  // Display-only fields (parsed from rawConfig during init)
  var cert: CertificateInfo?
  var ca: [CertificateInfo]
  var connected: Bool?  //TODO: active is a better name
  var status: String?
  var logFile: String?
  var alwaysOn: Bool
  var errors: [String]

  // Fields parsed from rawConfig for VPN service use (not encoded to Flutter)
  var mtu: Int
  var unsafeRoutes: [UnsafeRoute]
  var dnsResolvers: [String]

  /// If true then this site needs to be migrated to the filesystem. Should be handled by the initiator of the site
  var needsToMigrateToFS: Bool = false

  var manager: NETunnelProviderManager?

  // The config.json content (no key/dnCredentials), used by getConfig()
  private(set) var configData: Data

  /// Creates a new site from a vpn manager instance. Mainly used by the UI. A manager is required to be able to edit the system profile
  convenience init(manager: NETunnelProviderManager) throws {
    //TODO: Throw an error and have Sites delete the site, notify the user instead of using !
    let proto = manager.protocolConfiguration as! NETunnelProviderProtocol
    try self.init(proto: proto)
    self.manager = manager
    self.connected = statusMap[manager.connection.status]
    self.status = statusString[manager.connection.status]
    self.alwaysOn = manager.isOnDemandEnabled
  }

  convenience init(proto: NETunnelProviderProtocol) throws {
    let dict = proto.providerConfiguration

    if dict?["config"] != nil {
      // Legacy: site config stored directly in VPN profile, save to filesystem
      let config = dict?["config"] as? Data ?? Data()
      let jsonString = String(data: config, encoding: .utf8) ?? "{}"

      try saveSiteToDisk(jsonString: jsonString)

      guard let obj = try? JSONSerialization.jsonObject(with: config),
        let map = obj as? [String: Any],
        let id = map["id"] as? String
      else {
        throw SiteError.nonConforming(site: nil)
      }

      try self.init(path: SiteList.getSiteConfigFile(id: id, createDir: false))
      self.needsToMigrateToFS = true
      return
    }

    guard let id = dict?["id"] as? String else {
      throw SiteError.nonConforming(site: dict)
    }

    try self.init(path: SiteList.getSiteConfigFile(id: id, createDir: false))
  }

  /// Creates a new site from a path on the filesystem. Mainly used by the VPN process or when in simulator where we lack a NEVPNManager
  convenience init(path: URL) throws {
    let configData = try ConfigMigrator.migrate(
      configData: Data(contentsOf: path), path: path)
    self.init(configData: configData)
  }

  init(configData: Data) {
    var err: NSError?

    self.configData = configData
    errors = []

    // Parse config JSON
    let configMap: [String: Any]
    if let obj = try? JSONSerialization.jsonObject(with: configData),
      let parsed = obj as? [String: Any]
    {
      configMap = parsed
    } else {
      configMap = [:]
    }

    name = configMap["name"] as? String ?? ""
    id = configMap["id"] as? String ?? ""
    sortKey = (configMap["sortKey"] as? NSNumber)?.intValue ?? 0
    managed = configMap["managed"] as? Bool ?? false
    lastManagedUpdate = configMap["lastManagedUpdate"] as? String
    rawConfig = configMap["rawConfig"] as? String ?? "{}"
    configVersion = (configMap["configVersion"] as? NSNumber)?.intValue ?? 1
    alwaysOn = false  // Overridden by init(manager:) if applicable

    // Default these to disconnected for the UI
    status = statusString[.disconnected]
    connected = false

    // Parse rawConfig JSON to extract fields
    let rawConfigMap: [String: Any]
    if let data = rawConfig.data(using: .utf8),
      let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    {
      rawConfigMap = parsed
    } else {
      errors.append("Failed to parse rawConfig")
      rawConfigMap = [:]
    }

    // Parse mtu from rawConfig
    let tun = rawConfigMap["tun"] as? [String: Any]
    mtu = tun?["mtu"] as? Int ?? 1300

    // Parse unsafeRoutes from rawConfig
    if let routes = tun?["unsafe_routes"] as? [[String: Any]] {
      unsafeRoutes = routes.compactMap { routeMap in
        guard let route = routeMap["route"] as? String,
          let via = routeMap["via"] as? String
        else {
          return nil
        }
        return UnsafeRoute(route: route, via: via, mtu: routeMap["mtu"] as? Int)
      }
    } else {
      unsafeRoutes = []
    }

    // Parse dnsResolvers from rawConfig
    if let resolvers = rawConfigMap["dns_resolvers"] as? [String] {
      dnsResolvers = resolvers
    } else {
      dnsResolvers = []
    }

    // Parse cert from rawConfig's pki.cert
    let pki = rawConfigMap["pki"] as? [String: Any]
    let certPem = pki?["cert"] as? String

    if let certPem = certPem, !certPem.isEmpty {
      do {
        let rawDetails = MobileNebulaParseCerts(certPem, &err)
        if err != nil {
          throw err!
        }

        var certs: [CertificateInfo]

        certs = try JSONDecoder().decode(
          [CertificateInfo].self, from: rawDetails.data(using: .utf8)!)
        if certs.count == 0 {
          throw SiteError.noCertificate
        }
        cert = certs[0]
        if !cert!.validity.valid {
          errors.append("Certificate is invalid: \(cert!.validity.reason)")
        }

      } catch {
        errors.append("Error while loading certificate: \(error.localizedDescription)")
      }
    } else {
      cert = nil
      errors.append("Error while loading certificate: no certificate found in config")
    }

    // Parse ca from rawConfig's pki.ca
    let caPem = pki?["ca"] as? String

    if let caPem = caPem, !caPem.isEmpty {
      do {
        err = nil
        let rawCaDetails = MobileNebulaParseCerts(caPem, &err)
        if err != nil {
          throw err!
        }
        ca = try JSONDecoder().decode(
          [CertificateInfo].self, from: rawCaDetails.data(using: .utf8)!)

        var hasErrors = false
        ca.forEach { cert in
          if !cert.validity.valid {
            hasErrors = true
          }
        }

        if hasErrors && !managed {
          errors.append("There are issues with 1 or more ca certificates")
        }

      } catch {
        ca = []
        errors.append("Error while loading certificate authorities: \(error.localizedDescription)")
      }
    } else {
      ca = []
      if !managed {
        errors.append(
          "Error while loading certificate authorities: no CA found in config")
      }
    }

    do {
      logFile = try SiteList.getSiteLogFile(id: self.id, createDir: true).path
    } catch {
      logFile = nil
      errors.append("Unable to create the site directory: \(error.localizedDescription)")
    }

    if managed && (try? getDNCredentials())?.invalid != false {
      errors.append("Unable to fetch managed updates - please re-enroll the device")
    }

    if errors.isEmpty {
      do {
        let key = try getKey()
        let strConfig = String(data: configData, encoding: .utf8)
        var testErr: NSError?

        MobileNebulaTestConfig(strConfig, key, &testErr)
        if testErr != nil {
          throw testErr!
        }
      } catch {
        errors.append("Config test error: \(error.localizedDescription)")
      }
    }
  }

  // Gets the private key from the keystore, we don't always need it in memory
  func getKey() throws -> String {
    guard let keyData = KeyChain.load(key: "\(id).key") else {
      throw SiteError.keyLoad
    }

    //TODO: make sure this is valid on return!
    return String(decoding: keyData, as: UTF8.self)
  }

  func getDNCredentials() throws -> DNCredentials {
    if !managed {
      throw SiteError.unmanagedGetCredentials
    }

    let rawDNCredentials = KeyChain.load(key: "\(id).dnCredentials")
    if rawDNCredentials == nil {
      throw SiteError.dnCredentialLoad
    }

    let decoder = JSONDecoder()
    return try decoder.decode(DNCredentials.self, from: rawDNCredentials!)
  }

  func invalidateDNCredentials() throws {
    let creds = try getDNCredentials()
    creds.invalid = true

    if !(try creds.save(siteID: self.id)) {
      throw SiteError.dnCredentialLoad
    }
  }

  func validateDNCredentials() throws {
    let creds = try getDNCredentials()
    creds.invalid = false

    if !(try creds.save(siteID: self.id)) {
      throw SiteError.dnCredentialSave
    }
  }

  func getConfig() -> Data {
    return configData
  }

  // Limits what we export to the UI
  private enum CodingKeys: String, CodingKey {
    case name
    case id
    case sortKey
    case managed
    case lastManagedUpdate
    case rawConfig
    case configVersion
    case cert
    case ca
    case connected
    case status
    case logFile
    case alwaysOn
    case errors
  }
}

class DNCredentials: Codable {
  var hostID: String
  var privateKey: String
  var counter: Int
  var trustedKeys: String
  var invalid: Bool {
    get { return _invalid ?? false }
    set { _invalid = newValue }
  }

  private var _invalid: Bool?

  func save(siteID: String) throws -> Bool {
    let encoder = JSONEncoder()
    let rawDNCredentials = try encoder.encode(self)

    return KeyChain.save(key: "\(siteID).dnCredentials", data: rawDNCredentials, managed: true)
  }

  enum CodingKeys: String, CodingKey {
    case hostID
    case privateKey
    case counter
    case trustedKeys
    case _invalid = "invalid"
  }
}
