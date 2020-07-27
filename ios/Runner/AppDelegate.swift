import UIKit
import Flutter
import MobileNebula
import NetworkExtension
import MMWormhole

enum ChannelName {
    static let vpn = "net.defined.mobileNebula/NebulaVpnService"
}

func MissingArgumentError(message: String, details: Any?) -> FlutterError {
    return FlutterError(code: "missing_argument", message: message, details: details)
}

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var sites: Sites?
    private var wormhole = MMWormhole(applicationGroupIdentifier: "group.net.defined.mobileNebula", optionalDirectory: "ipc")
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        guard let controller = window?.rootViewController as? FlutterViewController else {
            fatalError("rootViewController is not type FlutterViewController")
        }
        
        sites = Sites(messenger: controller.binaryMessenger)
        let channel = FlutterMethodChannel(name: ChannelName.vpn, binaryMessenger: controller.binaryMessenger)
        
        NSKeyedUnarchiver.setClass(IPCMessage.classForKeyedUnarchiver(), forClassName: "NebulaNetworkExtension.IPCMessage")
        wormhole.listenForMessage(withIdentifier: "nebula", listener: self.wormholeListener)
        
        channel.setMethodCallHandler({(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "nebula.parseCerts": return self.nebulaParseCerts(call: call, result: result)
            case "nebula.generateKeyPair": return self.nebulaGenerateKeyPair(result: result)
            case "nebula.renderConfig": return self.nebulaRenderConfig(call: call, result: result)
                
            case "listSites": return self.listSites(result: result)
            case "deleteSite": return self.deleteSite(call: call, result: result)
            case "saveSite": return self.saveSite(call: call, result: result)
            case "startSite": return self.startSite(call: call, result: result)
            case "stopSite": return self.stopSite(call: call, result: result)
                
            case "active.listHostmap": self.activeListHostmap(call: call, result: result)
            case "active.listPendingHostmap": self.activeListPendingHostmap(call: call, result: result)
            case "active.getHostInfo": self.activeGetHostInfo(call: call, result: result)
            case "active.setRemoteForTunnel": self.activeSetRemoteForTunnel(call: call, result: result)
            case "active.closeTunnel": self.activeCloseTunnel(call: call, result: result)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        })
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func nebulaParseCerts(call: FlutterMethodCall, result: FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, String> else { return result(NoArgumentsError()) }
        guard let certs = args["certs"] else { return result(MissingArgumentError(message: "certs is a required argument")) }
        
        var err: NSError?
        let json = MobileNebulaParseCerts(certs, &err)
        if (err != nil) {
            return result(CallFailedError(message: "Error while parsing certificate(s)", details: err!.localizedDescription))
        }
        
        return result(json)
    }
    
    func nebulaGenerateKeyPair(result: FlutterResult) {
        var err: NSError?
        let kp = MobileNebulaGenerateKeyPair(&err)
        if (err != nil) {
            return result(CallFailedError(message: "Error while generating key pairs", details: err!.localizedDescription))
        }
        
        return result(kp)
    }
    
    func nebulaRenderConfig(call: FlutterMethodCall, result: FlutterResult) {
        guard let config = call.arguments as? String else { return result(NoArgumentsError()) }
        
        var err: NSError?
        print(config)
        let yaml = MobileNebulaRenderConfig(config, "<hidden>", &err)
        if (err != nil) {
            return result(CallFailedError(message: "Error while rendering config", details: err!.localizedDescription))
        }
        
        return result(yaml)
    }
    
    func listSites(result: @escaping FlutterResult) {
        self.sites?.loadSites { (sites, err) -> () in
            if (err != nil) {
                return result(CallFailedError(message: "Failed to load site list", details: err!.localizedDescription))
            }

            let encoder = JSONEncoder()
            let data = try! encoder.encode(sites)
            let ret = String(data: data, encoding: .utf8)
            result(ret)
        }
    }
    
    func deleteSite(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let id = call.arguments as? String else { return result(NoArgumentsError()) }
        //TODO: stop the site if its running currently
        self.sites?.deleteSite(id: id) { error in
            if (error != nil) {
                result(CallFailedError(message: "Failed to delete site", details: error!.localizedDescription))
            }
            
            result(nil)
        }
    }
    
    func saveSite(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let json = call.arguments as? String else { return result(NoArgumentsError()) }
        guard let data = json.data(using: .utf8) else { return result(NoArgumentsError()) }
        
        guard let site = try? JSONDecoder().decode(IncomingSite.self, from: data) else {
            return result(NoArgumentsError())
        }
        
        let oldSite = self.sites?.getSite(id: site.id)
        site.save(manager: oldSite?.manager) { error in
            if (error != nil) {
                return result(CallFailedError(message: "Failed to save site", details: error!.localizedDescription))
            }

            result(nil)
        }
    }
    
    func startSite(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, String> else { return result(NoArgumentsError()) }
        guard let id = args["id"] else { return result(MissingArgumentError(message: "id is a required argument")) }
#if targetEnvironment(simulator)
        let updater = self.sites?.getUpdater(id: id)
        updater?.update(connected: true)
        
#else
        let manager = self.sites?.getSite(id: id)?.manager
        manager?.loadFromPreferences{ error in
            //TODO: Handle load error
            // This is silly but we need to enable the site each time to avoid situations where folks have multiple sites
            manager?.isEnabled = true
            manager?.saveToPreferences{ error in
                //TODO: Handle load error
                manager?.loadFromPreferences{ error in
                    //TODO: Handle load error
                    do {
                        try manager?.connection.startVPNTunnel()
                    } catch {
                        return result(CallFailedError(message: "Could not start site", details: error.localizedDescription))
                    }
                    
                    return result(nil)
                }
            }
        }
#endif
    }
    
    func stopSite(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, String> else { return result(NoArgumentsError()) }
        guard let id = args["id"] else { return result(MissingArgumentError(message: "id is a required argument")) }
#if targetEnvironment(simulator)
        let updater = self.sites?.getUpdater(id: id)
        updater?.update(connected: false)
        
#else
        let manager = self.sites?.getSite(id: id)?.manager
        manager?.loadFromPreferences{ error in
            //TODO: Handle load error
            
            manager?.connection.stopVPNTunnel()
            return result(nil)
        }
#endif
    }
    
    func activeListHostmap(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, String> else { return result(NoArgumentsError()) }
        guard let id = args["id"] else { return result(MissingArgumentError(message: "id is a required argument")) }
        //TODO: match id for safety?
        wormholeRequestWithCallback(type: "listHostmap", arguments: nil) { (data, err) -> () in
            if (err != nil) {
                return result(CallFailedError(message: err!.localizedDescription))
            }
            
            result(data)
        }
    }
    
    func activeListPendingHostmap(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, String> else { return result(NoArgumentsError()) }
        guard let id = args["id"] else { return result(MissingArgumentError(message: "id is a required argument")) }
        //TODO: match id for safety?
        wormholeRequestWithCallback(type: "listPendingHostmap", arguments: nil) { (data, err) -> () in
            if (err != nil) {
                return result(CallFailedError(message: err!.localizedDescription))
            }
            
            result(data)
        }
    }
    
    func activeGetHostInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, Any> else { return result(NoArgumentsError()) }
        guard let id = args["id"] as? String else { return result(MissingArgumentError(message: "id is a required argument")) }
        guard let vpnIp = args["vpnIp"] as? String else { return result(MissingArgumentError(message: "vpnIp is a required argument")) }
        let pending = args["pending"] as? Bool ?? false
        
        //TODO: match id for safety?
        wormholeRequestWithCallback(type: "getHostInfo", arguments: ["vpnIp": vpnIp, "pending": pending]) { (data, err) -> () in
            if (err != nil) {
                return result(CallFailedError(message: err!.localizedDescription))
            }
            
            result(data)
        }
    }
    
    func activeSetRemoteForTunnel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, String> else { return result(NoArgumentsError()) }
        guard let id = args["id"] else { return result(MissingArgumentError(message: "id is a required argument")) }
        guard let vpnIp = args["vpnIp"] else { return result(MissingArgumentError(message: "vpnIp is a required argument")) }
        guard let addr = args["addr"] else { return result(MissingArgumentError(message: "addr is a required argument")) }
        
        //TODO: match id for safety?
        wormholeRequestWithCallback(type: "setRemoteForTunnel", arguments: ["vpnIp": vpnIp, "addr": addr]) { (data, err) -> () in
            if (err != nil) {
                return result(CallFailedError(message: err!.localizedDescription))
            }
            
            result(data)
        }
    }
    
    func activeCloseTunnel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? Dictionary<String, String> else { return result(NoArgumentsError()) }
        guard let id = args["id"] else { return result(MissingArgumentError(message: "id is a required argument")) }
        guard let vpnIp = args["vpnIp"] else { return result(MissingArgumentError(message: "vpnIp is a required argument")) }
        
        //TODO: match id for safety?
        wormholeRequestWithCallback(type: "closeTunnel", arguments: ["vpnIp": vpnIp]) { (data, err) -> () in
            if (err != nil) {
                return result(CallFailedError(message: err!.localizedDescription))
            }
            
            result(data as? Bool ?? false)
        }
    }
    
    func wormholeListener(msg: Any?) {
        guard let call = msg as? IPCMessage else {
            print("Failed to decode IPCMessage from network extension")
            return
        }
        
        switch call.type {
        case "error":
            guard let updater = self.sites?.getUpdater(id: call.id) else {
                return print("Could not find site to deliver error to \(call.id): \(String(describing: call.message))")
            }
            updater.setError(err: call.message as! String)
            
        default:
            print("Unknown IPC message type \(call.type)")
        }
    }
    
    func wormholeRequestWithCallback(type: String, arguments: Dictionary<String, Any>?, completion: @escaping (Any?, Error?) -> ()) {
        let uuid = UUID().uuidString
    
        wormhole.listenForMessage(withIdentifier: uuid) { msg -> () in
            self.wormhole.stopListeningForMessage(withIdentifier: uuid)
            
            guard let call = msg as? IPCMessage else {
                completion("", "Failed to decode IPCMessage callback from network extension")
                return
            }
            
            switch call.type {
            case "error":
                completion("", call.message as? String ?? "Failed to convert error")
            case "success":
                completion(call.message, nil)
                
            default:
                completion("", "Unknown IPC message type \(call.type)")
            }
        }
        
        wormhole.passMessageObject(IPCRequest(callbackId: uuid, type: type, arguments: arguments), identifier: "app")
    }
}

func MissingArgumentError(message: String, details: Error? = nil) -> FlutterError {
    return FlutterError(code: "missingArgument", message: message, details: details)
}

func NoArgumentsError(message: String? = "no arguments were provided or could not be deserialized", details: Error? = nil) -> FlutterError {
    return FlutterError(code: "noArguments", message: message, details: details)
}

func CallFailedError(message: String, details: String? = "") -> FlutterError {
    return FlutterError(code: "callFailed", message: message, details: details)
}
