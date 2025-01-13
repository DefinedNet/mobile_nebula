import NetworkExtension
import MobileNebula
import SwiftyJSON
import os.log

let log = Logger(subsystem: "net.defined.mobileNebula", category: "Site")

enum SiteError: Error {
    case nonConforming(site: [String : Any]?)
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
    var fingerprint: String
    var signature: String
    var details: CertificateDetails

    /// An empty initializer to make error reporting easier
    init() {
        fingerprint = ""
        signature = ""
        details = CertificateDetails()
    }
}

struct CertificateDetails: Codable {
    var name: String
    var notBefore: String
    var notAfter: String
    var publicKey: String
    var groups: [String]
    var ips: [String]
    var subnets: [String]
    var isCa: Bool
    var issuer: String

    /// An empty initializer to make error reporting easier
    init() {
        name = ""
        notBefore = ""
        notAfter = ""
        publicKey = ""
        groups = []
        ips = ["ERROR"]
        subnets = []
        isCa = false
        issuer = ""
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

let statusMap: Dictionary<NEVPNStatus, Bool> = [
    NEVPNStatus.invalid: false,
    NEVPNStatus.disconnected: false,
    NEVPNStatus.connecting: false,
    NEVPNStatus.connected: true,
    NEVPNStatus.reasserting: true,
    NEVPNStatus.disconnecting: true,
]

let statusString: Dictionary<NEVPNStatus, String> = [
    NEVPNStatus.invalid: "Invalid configuration",
    NEVPNStatus.disconnected: "Disconnected",
    NEVPNStatus.connecting: "Connecting...",
    NEVPNStatus.connected: "Connected",
    NEVPNStatus.reasserting: "Reasserting...",
    NEVPNStatus.disconnecting: "Disconnecting...",
]

// Represents a site that was pulled out of the system configuration
class Site: Codable {
    // Stored in manager
    var name: String
    var id: String

    // Stored in proto
    var staticHostmap: Dictionary<String, StaticHosts>
    var unsafeRoutes: [UnsafeRoute]
    var cert: CertificateInfo?
    var ca: [CertificateInfo]
    var lhDuration: Int
    var port: Int
    var mtu: Int
    var cipher: String
    var sortKey: Int
    var logVerbosity: String
    var connected: Bool? //TODO: active is a better name
    var status: String?
    var logFile: String?
    var managed: Bool
    // The following fields are present if managed = true
    var lastManagedUpdate: String?
    var rawConfig: String?

    /// If true then this site needs to be migrated to the filesystem. Should be handled by the initiator of the site
    var needsToMigrateToFS: Bool = false

    // A list of error encountered when trying to rehydrate a site from config
    var errors: [String]

    var manager: NETunnelProviderManager?

    var incomingSite: IncomingSite?

    /// Creates a new site from a vpn manager instance. Mainly used by the UI. A manager is required to be able to edit the system profile
    convenience init(manager: NETunnelProviderManager) throws {
        //TODO: Throw an error and have Sites delete the site, notify the user instead of using !
        let proto = manager.protocolConfiguration as! NETunnelProviderProtocol
        try self.init(proto: proto)
        self.manager = manager
        self.connected = statusMap[manager.connection.status]
        self.status = statusString[manager.connection.status]
    }

    convenience init(proto: NETunnelProviderProtocol) throws {
        let dict = proto.providerConfiguration

        if dict?["config"] != nil {
            let config = dict?["config"] as? Data ?? Data()
            let decoder = JSONDecoder()
            let incoming = try decoder.decode(IncomingSite.self, from: config)
            self.init(incoming: incoming)
            self.needsToMigrateToFS = true
            return
        }

        let id = dict?["id"] as? String ?? nil
        if id == nil {
            throw SiteError.nonConforming(site: dict)
        }

        try self.init(path: SiteList.getSiteConfigFile(id: id!, createDir: false))
    }

    /// Creates a new site from a path on the filesystem. Mainly ussed by the VPN process or when in simulator where we lack a NEVPNManager
    convenience init(path: URL) throws {
        let config = try Data(contentsOf: path)
        let decoder = JSONDecoder()
        let incoming = try decoder.decode(IncomingSite.self, from: config)
        self.init(incoming: incoming)
    }

    init(incoming: IncomingSite) {
        var err: NSError?

        incomingSite = incoming
        errors = []
        name = incoming.name
        id = incoming.id
        staticHostmap = incoming.staticHostmap
        unsafeRoutes = incoming.unsafeRoutes ?? []
        lhDuration = incoming.lhDuration
        port = incoming.port
        cipher = incoming.cipher
        sortKey = incoming.sortKey ?? 0
        logVerbosity = incoming.logVerbosity ?? "info"
        mtu = incoming.mtu ?? 1300
        managed = incoming.managed ?? false
        lastManagedUpdate = incoming.lastManagedUpdate
        rawConfig = incoming.rawConfig

        do {
            let rawCert = incoming.cert
            let rawDetails = MobileNebulaParseCerts(rawCert, &err)
            if (err != nil) {
                throw err!
            }

            var certs: [CertificateInfo]

            certs = try JSONDecoder().decode([CertificateInfo].self, from: rawDetails.data(using: .utf8)!)
            if (certs.count == 0) {
                throw SiteError.noCertificate
            }
            cert = certs[0]
            if (!cert!.validity.valid) {
                errors.append("Certificate is invalid: \(cert!.validity.reason)")
            }

        } catch {
            errors.append("Error while loading certificate: \(error.localizedDescription)")
        }

        do {
            let rawCa = incoming.ca
            let rawCaDetails = MobileNebulaParseCerts(rawCa, &err)
            if (err != nil) {
                throw err!
            }
            ca = try JSONDecoder().decode([CertificateInfo].self, from: rawCaDetails.data(using: .utf8)!)

            var hasErrors = false
            ca.forEach { cert in
                if (!cert.validity.valid) {
                    hasErrors = true
                }
            }

            if (hasErrors && !managed) {
                errors.append("There are issues with 1 or more ca certificates")
            }

        } catch {
            ca = []
            errors.append("Error while loading certificate authorities: \(error.localizedDescription)")
        }

        do {
            logFile = try SiteList.getSiteLogFile(id: self.id, createDir: true).path
        } catch {
            logFile = nil
            errors.append("Unable to create the site directory: \(error.localizedDescription)")
        }

        if (managed && (try? getDNCredentials())?.invalid != false) {
            errors.append("Unable to fetch managed updates - please re-enroll the device")
        }

        if (errors.isEmpty) {
            do {
                let encoder = JSONEncoder()
                let rawConfig = try encoder.encode(incoming)
                let key = try getKey()
                let strConfig = String(data: rawConfig, encoding: .utf8)
                var err: NSError?

                MobileNebulaTestConfig(strConfig, key, &err)
                if (err != nil) {
                    throw err!
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
        if (!managed) {
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

        if (!(try creds.save(siteID: self.id))) {
            throw SiteError.dnCredentialLoad
        }
    }

    func validateDNCredentials() throws {
        let creds = try getDNCredentials()
        creds.invalid = false

        if (!(try creds.save(siteID: self.id))) {
            throw SiteError.dnCredentialSave
        }
    }

    func getConfig() throws -> Data {
        return try self.incomingSite!.getConfig()
    }

    // Limits what we export to the UI
    private enum CodingKeys: String, CodingKey {
        case name
        case id
        case staticHostmap
        case cert
        case ca
        case lhDuration
        case port
        case cipher
        case sortKey
        case connected
        case status
        case logFile
        case unsafeRoutes
        case logVerbosity
        case errors
        case mtu
        case managed
        case lastManagedUpdate
        case rawConfig
    }
}

class StaticHosts: Codable {
    var lighthouse: Bool
    var destinations: [String]
}

class UnsafeRoute: Codable {
    var route: String
    var via: String
    var mtu: Int?
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

// This class represents a site coming in from flutter, meant only to be saved and re-loaded as a proper Site
struct IncomingSite: Codable {
    var name: String
    var id: String
    var staticHostmap: Dictionary<String, StaticHosts>
    var unsafeRoutes: [UnsafeRoute]?
    var cert: String?
    var ca: String?
    var lhDuration: Int
    var port: Int
    var mtu: Int?
    var cipher: String
    var sortKey: Int?
    var logVerbosity: String?
    var key: String?
    var managed: Bool?
    // The following fields are present if managed = true
    var dnCredentials: DNCredentials?
    var lastManagedUpdate: String?
    var rawConfig: String?

    func getConfig() throws -> Data {
        let encoder = JSONEncoder()
        var config = self

        config.key = nil
        config.dnCredentials = nil

        return try encoder.encode(config)
    }

    func save(manager: NETunnelProviderManager?, saveToManager: Bool = true, callback: @escaping (Error?) -> ()) {
        let configPath: URL

        do {
            configPath = try SiteList.getSiteConfigFile(id: self.id, createDir: true)

        } catch {
            callback(error)
            return
        }

        log.notice("Saving to \(configPath, privacy: .public)")
        do {
            if (self.key != nil) {
                let data = self.key!.data(using: .utf8)
                if (!KeyChain.save(key: "\(self.id).key", data: data!, managed: self.managed ?? false)) {
                    return callback(SiteError.keySave)
                }
            }

            do {
                if ((try self.dnCredentials?.save(siteID: self.id)) == false) {
                    return callback(SiteError.dnCredentialSave)
                }
            } catch {
                return callback(error)
            }

            try self.getConfig().write(to: configPath)

        } catch {
            return callback(error)
        }


#if targetEnvironment(simulator)
        // We are on a simulator and there is no NEVPNManager for us to interact with
        callback(nil)
#else
        if saveToManager {
            self.saveToManager(manager: manager, callback: callback)
        } else {
            callback(nil)
        }
#endif
    }

    private func saveToManager(manager: NETunnelProviderManager?, callback: @escaping (Error?) -> ()) {
        if (manager != nil) {
            // We need to refresh our settings to properly update config
            manager?.loadFromPreferences { error in
                if (error != nil) {
                    return callback(error)
                }

                return self.finishSaveToManager(manager: manager!, callback: callback)
            }
            return
        }

        return finishSaveToManager(manager: NETunnelProviderManager(), callback: callback)
    }

    private func finishSaveToManager(manager: NETunnelProviderManager, callback: @escaping (Error?) -> ()) {
        // Stuff our details in the protocol
        let proto = manager.protocolConfiguration as? NETunnelProviderProtocol ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "net.defined.mobileNebula.NebulaNetworkExtension";
        // WARN: If we stop setting providerConfiguration["id"] here, we'll need to use something else to match
        // managers in PacketTunnelProvider.findManager
        proto.providerConfiguration = ["id": self.id]
        proto.serverAddress = "Nebula"

        // Finish up the manager, this is what stores everything at the system level
        manager.protocolConfiguration = proto
        //TODO: cert name?        manager.protocolConfiguration?.username

        //TODO: This is what is shown on the vpn page. We should add more identifying details in
        manager.localizedDescription = self.name
        manager.isEnabled = true

        manager.saveToPreferences{ error in
            return callback(error)
        }
    }
}
