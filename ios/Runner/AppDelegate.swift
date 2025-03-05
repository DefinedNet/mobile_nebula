@preconcurrency import Flutter
import MobileNebula
import NetworkExtension
import SwiftyJSON
import UIKit

enum ChannelName {
  static let vpn = "net.defined.mobileNebula/NebulaVpnService"
}

func MissingArgumentError(message: String, details: Any?) -> FlutterError {
  return FlutterError(code: "missing_argument", message: message, details: details)
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let dnUpdater = DNUpdater()
  private let apiClient = APIClient()
  private var sites: Sites?
  private var ui: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    Task {
      for await site in dnUpdater.siteUpdates {
        // Signal the site has changed in case the current site details screen is active
        let container = self.sites?.getContainer(id: site.id)
        if container != nil {
          // Update references to the site with the new site config
          container!.site = site
          container!.updater.update(connected: site.connected ?? false, replaceSite: site)
        }

        // Signal to the main screen to reload
        self.ui?.invokeMethod("refreshSites", arguments: nil)
      }
    }

    guard let controller = window?.rootViewController as? FlutterViewController else {
      fatalError("rootViewController is not type FlutterViewController")
    }

    sites = Sites(messenger: controller.binaryMessenger)
    ui = FlutterMethodChannel(name: ChannelName.vpn, binaryMessenger: controller.binaryMessenger)

    ui!.setMethodCallHandler({ (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "nebula.parseCerts": return self.nebulaParseCerts(call: call, result: result)
      case "nebula.generateKeyPair": return self.nebulaGenerateKeyPair(result: result)
      case "nebula.renderConfig": return self.nebulaRenderConfig(call: call, result: result)
      case "nebula.verifyCertAndKey": return self.nebulaVerifyCertAndKey(call: call, result: result)

      case "dn.enroll": return self.dnEnroll(call: call, result: result)

      case "listSites": return self.listSites(result: result)
      case "deleteSite": return self.deleteSite(call: call, result: result)
      case "saveSite": return self.saveSite(call: call, result: result)
      case "startSite": return self.startSite(call: call, result: result)
      case "stopSite": return self.stopSite(call: call, result: result)

      case "active.listHostmap":
        self.vpnRequest(command: "listHostmap", arguments: call.arguments, result: result)
      case "active.listPendingHostmap":
        self.vpnRequest(command: "listPendingHostmap", arguments: call.arguments, result: result)
      case "active.getHostInfo":
        self.vpnRequest(command: "getHostInfo", arguments: call.arguments, result: result)
      case "active.setRemoteForTunnel":
        self.vpnRequest(command: "setRemoteForTunnel", arguments: call.arguments, result: result)
      case "active.closeTunnel":
        self.vpnRequest(command: "closeTunnel", arguments: call.arguments, result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    })

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func nebulaParseCerts(call: FlutterMethodCall, result: FlutterResult) {
    guard let args = call.arguments as? [String: String] else { return result(NoArgumentsError()) }
    guard let certs = args["certs"] else {
      return result(MissingArgumentError(message: "certs is a required argument"))
    }

    var err: NSError?
    let json = MobileNebulaParseCerts(certs, &err)
    if err != nil {
      return result(
        CallFailedError(
          message: "Error while parsing certificate(s)", details: err!.localizedDescription))
    }

    return result(json)
  }

  func nebulaVerifyCertAndKey(call: FlutterMethodCall, result: FlutterResult) {
    guard let args = call.arguments as? [String: String] else { return result(NoArgumentsError()) }
    guard let cert = args["cert"] else {
      return result(MissingArgumentError(message: "cert is a required argument"))
    }
    guard let key = args["key"] else {
      return result(MissingArgumentError(message: "key is a required argument"))
    }

    var err: NSError?
    var validd: ObjCBool = false
    let valid = MobileNebulaVerifyCertAndKey(cert, key, &validd, &err)
    if err != nil {
      return result(
        CallFailedError(
          message: "Error while verifying certificate and private key",
          details: err!.localizedDescription))
    }

    return result(valid)
  }

  func nebulaGenerateKeyPair(result: FlutterResult) {
    var err: NSError?
    let kp = MobileNebulaGenerateKeyPair(&err)
    if err != nil {
      return result(
        CallFailedError(
          message: "Error while generating key pairs", details: err!.localizedDescription))
    }

    return result(kp)
  }

  func nebulaRenderConfig(call: FlutterMethodCall, result: FlutterResult) {
    guard let config = call.arguments as? String else { return result(NoArgumentsError()) }

    var err: NSError?
    let yaml = MobileNebulaRenderConfig(config, "<hidden>", &err)
    if err != nil {
      return result(
        CallFailedError(message: "Error while rendering config", details: err!.localizedDescription)
      )
    }

    return result(yaml)
  }

  func dnEnroll(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let code = call.arguments as? String else { return result(NoArgumentsError()) }

    do {
      let site = try apiClient.enroll(code: code)

      let oldSite = self.sites?.getSite(id: site.id)
      site.save(manager: oldSite?.manager) { error in
        if error != nil {
          return result(
            CallFailedError(message: "Failed to enroll", details: error!.localizedDescription))
        }

        result(nil)
      }
    } catch {
      return result(
        CallFailedError(message: "Error from DN api", details: error.localizedDescription))
    }
  }

  func listSites(result: @escaping FlutterResult) {
    self.sites?.loadSites { (sites, err) -> Void in
      if err != nil {
        return result(
          CallFailedError(message: "Failed to load site list", details: err!.localizedDescription))
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
      if error != nil {
        result(
          CallFailedError(message: "Failed to delete site", details: error!.localizedDescription))
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
      if error != nil {
        return result(
          CallFailedError(message: "Failed to save site", details: error!.localizedDescription))
      }

      self.sites?.loadSites { _, _ in
        result(nil)
      }
    }
  }

  func startSite(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: String] else { return result(NoArgumentsError()) }
    guard let id = args["id"] else {
      return result(MissingArgumentError(message: "id is a required argument"))
    }

    #if targetEnvironment(simulator)
      let updater = self.sites?.getUpdater(id: id)
      updater?.update(connected: true)
    #else
      let container = self.sites?.getContainer(id: id)
      let manager = container?.site.manager

      manager?.loadFromPreferences { error in
        //TODO: Handle load error
        // This is silly but we need to enable the site each time to avoid situations where folks have multiple sites
        manager?.isEnabled = true
        manager?.saveToPreferences { error in
          //TODO: Handle load error
          manager?.loadFromPreferences { error in
            //TODO: Handle load error
            do {
              container?.updater.startFunc = { () -> Void in
                return self.vpnRequest(command: "start", arguments: args, result: result)
              }
              try manager?.connection.startVPNTunnel(options: ["expectStart": NSNumber(1)])
            } catch {
              return result(
                CallFailedError(
                  message: "Could not start site", details: error.localizedDescription))
            }
          }
        }
      }
    #endif
  }

  func stopSite(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: String] else { return result(NoArgumentsError()) }
    guard let id = args["id"] else {
      return result(MissingArgumentError(message: "id is a required argument"))
    }
    #if targetEnvironment(simulator)
      let updater = self.sites?.getUpdater(id: id)
      updater?.update(connected: false)

    #else
      let manager = self.sites?.getSite(id: id)?.manager
      manager?.loadFromPreferences { error in
        //TODO: Handle load error

        manager?.connection.stopVPNTunnel()
        return result(nil)
      }
    #endif
  }

  func vpnRequest(command: String, arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any] else { return result(NoArgumentsError()) }
    guard let id = args["id"] as? String else {
      return result(MissingArgumentError(message: "id is a required argument"))
    }
    let container = sites?.getContainer(id: id)

    if container == nil {
      // No site for this id
      return result(nil)
    }

    if !(container!.site.connected ?? false) {
      // Site isn't connected, no point in sending a command
      return result(nil)
    }

    if let session = container!.site.manager?.connection as? NETunnelProviderSession {
      do {
        try session.sendProviderMessage(
          try JSONEncoder().encode(IPCRequest(command: command, arguments: JSON(args)))
        ) { data in
          if data == nil {
            return result(nil)
          }

          //print(String(decoding: data!, as: UTF8.self))
          guard let res = try? JSONDecoder().decode(IPCResponse.self, from: data!) else {
            return result(CallFailedError(message: "Failed to decode response"))
          }

          if res.type == .success {
            return result(res.message?.object)
          }

          return result(
            CallFailedError(message: res.message?.debugDescription ?? "Failed to convert error"))
        }
      } catch {
        return result(CallFailedError(message: error.localizedDescription))
      }
    } else {
      //TODO: we have a site without a manager, things have gone weird. How to handle since this shouldn't happen?
      result(nil)
    }
  }
}

func MissingArgumentError(message: String, details: (any Error)? = nil) -> FlutterError {
  return FlutterError(code: "missingArgument", message: message, details: details)
}

func NoArgumentsError(
  message: String? = "no arguments were provided or could not be deserialized",
  details: (any Error)? = nil
) -> FlutterError {
  return FlutterError(code: "noArguments", message: message, details: details)
}

func CallFailedError(message: String, details: String? = "") -> FlutterError {
  return FlutterError(code: "callFailed", message: message, details: details)
}
