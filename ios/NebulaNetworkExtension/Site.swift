import NetworkExtension
import MobileNebula

extension String: Error {}

class IPCMessage: NSObject, NSCoding {
    var id: String
    var type: String
    var message: Any?
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(id, forKey: "id")
        aCoder.encode(type, forKey: "type")
        aCoder.encode(message, forKey: "message")
    }

    required init(coder aDecoder: NSCoder) {
        id = aDecoder.decodeObject(forKey: "id") as! String
        type = aDecoder.decodeObject(forKey: "type") as! String
        message = aDecoder.decodeObject(forKey: "message") as Any?
    }
    
    init(id: String, type: String, message: Any) {
        self.id = id
        self.type = type
        self.message = message
    }
}

class IPCRequest: NSObject, NSCoding {
    var type: String
    var callbackId: String
    var arguments: Dictionary<String, Any>?
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(type, forKey: "type")
        aCoder.encode(arguments, forKey: "arguments")
        aCoder.encode(callbackId, forKey: "callbackId")
    }
    
    required init(coder aDecoder: NSCoder) {
        callbackId = aDecoder.decodeObject(forKey: "callbackId") as! String
        type = aDecoder.decodeObject(forKey: "type") as! String
        arguments = aDecoder.decodeObject(forKey: "arguments") as? Dictionary<String, Any>
    }
    
    init(callbackId: String, type: String, arguments: Dictionary<String, Any>?) {
        self.callbackId = callbackId
        self.type = type
        self.arguments = arguments
    }
    
    init(callbackId: String, type: String) {
        self.callbackId = callbackId
        self.type = type
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
    
    /// An empty initilizer to make error reporting easier
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
    
    /// An empty initilizer to make error reporting easier
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
    NEVPNStatus.connecting: true,
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
struct Site: Codable {
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
    var logLocalTZ: Bool?
    var logVerbosity: String
    var connected: Bool?
    var status: String?
    var logFile: String?
    
    // A list of error encountered when trying to rehydrate a site from config
    var errors: [String]
    
    // We initialize to avoid an error with Codable, there is probably a better way since manager must be present for a Site but is not codable
    var manager: NETunnelProviderManager = NETunnelProviderManager()
    
    // Creates a new site from a vpn manager instance
    init(manager: NETunnelProviderManager) throws {
        //TODO: Throw an error and have Sites delete the site, notify the user instead of using !
        let proto = manager.protocolConfiguration as! NETunnelProviderProtocol
        try self.init(proto: proto)
        self.manager = manager
        self.connected = statusMap[manager.connection.status]
        self.status = statusString[manager.connection.status]
    }
    
    init(proto: NETunnelProviderProtocol) throws {
        let dict = proto.providerConfiguration
        let config = dict?["config"] as? Data ?? Data()
        let decoder = JSONDecoder()
        let incoming = try decoder.decode(IncomingSite.self, from: config)
        self.init(incoming: incoming)
    }
    
    init(incoming: IncomingSite) {
        var err: NSError?
        
        errors = []
        name = incoming.name
        id = incoming.id
        staticHostmap = incoming.staticHostmap
        unsafeRoutes = incoming.unsafeRoutes ?? []
        
        do {
            let rawCert = incoming.cert
            let rawDetails = MobileNebulaParseCerts(rawCert, &err)
            if (err != nil) {
                throw err!
            }
            
            var certs: [CertificateInfo]
            
            certs = try JSONDecoder().decode([CertificateInfo].self, from: rawDetails.data(using: .utf8)!)
            if (certs.count == 0) {
                throw "No certificate found"
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
            
            if (hasErrors) {
                errors.append("There are issues with 1 or more ca certificates")
            }
            
        } catch {
            ca = []
            errors.append("Error while loading certificate authorities: \(error.localizedDescription)")
        }
        
        lhDuration = incoming.lhDuration
        port = incoming.port
        cipher = incoming.cipher
        sortKey = incoming.sortKey ?? 0
        logLocalTZ = incoming.logLocalTZ ?? false
        logVerbosity = incoming.logVerbosity ?? "info"
        mtu = incoming.mtu ?? 1300
        logFile = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.net.defined.mobileNebula")?.appendingPathComponent(id).appendingPathExtension("log").path
        
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
            throw "failed to get key material from keychain"
        }

        //TODO: make sure this is valid on return!
        return String(decoding: keyData, as: UTF8.self)
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
        case logLocalTZ
        case logVerbosity
        case errors
        case mtu
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

// This class represents a site coming in from flutter, meant only to be saved and re-loaded as a proper Site
struct IncomingSite: Codable {
    var name: String
    var id: String
    var staticHostmap: Dictionary<String, StaticHosts>
    var unsafeRoutes: [UnsafeRoute]?
    var cert: String
    var ca: String
    var lhDuration: Int
    var port: Int
    var mtu: Int?
    var cipher: String
    var sortKey: Int?
    var logLocalTZ: Bool?
    var logVerbosity: String?
    var key: String?
    
    func save(manager: NETunnelProviderManager?, callback: @escaping (Error?) -> ()) {
#if targetEnvironment(simulator)
        let fileManager = FileManager.default
        let sitePath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("sites").appendingPathComponent(self.id)
        let encoder = JSONEncoder()

        do {
            var config = self
            config.key = nil
            let rawConfig = try encoder.encode(config)
            try rawConfig.write(to: sitePath)
        } catch {
            return callback(error)
        }
        
        callback(nil)
#else
        if (manager != nil) {
            // We need to refresh our settings to properly update config
            manager?.loadFromPreferences { error in
                if (error != nil) {
                    return callback(error)
                }
                
                return self.finish(manager: manager!, callback: callback)
            }
            return
        }
        
        return finish(manager: NETunnelProviderManager(), callback: callback)
#endif
    }
    
    private func finish(manager: NETunnelProviderManager, callback: @escaping (Error?) -> ()) {
        var config = self
        
        // Store the private key if it was provided
        if (config.key != nil) {
            //TODO: should we ensure the resulting data is big enough? (conversion didn't fail)
            let data = config.key!.data(using: .utf8)
            if (!KeyChain.save(key: "\(config.id).key", data: data!)) {
                return callback("failed to store key material in keychain")
            }
        }
        
        // Zero out the key so that we don't save it in the profile
        config.key = nil

        // Stuff our details in the protocol
        let proto = manager.protocolConfiguration as? NETunnelProviderProtocol ?? NETunnelProviderProtocol()
        let encoder = JSONEncoder()
        let rawConfig: Data

        // We tried using NSSecureCoder but that was obnoxious and didn't work so back to JSON
        do {
            rawConfig = try encoder.encode(config)
        } catch {
            return callback(error)
        }
        
        proto.providerConfiguration = ["config": rawConfig]
        proto.serverAddress = "Nebula"
        
        // Finish up the manager, this is what stores everything at the system level
        manager.protocolConfiguration = proto
        //TODO: cert name?        manager.protocolConfiguration?.username

        //TODO: This is what is shown on the vpn page. We should add more identifying details in
        manager.localizedDescription = config.name
        manager.isEnabled = true

        manager.saveToPreferences{ error in
            return callback(error)
        }
    }
}
