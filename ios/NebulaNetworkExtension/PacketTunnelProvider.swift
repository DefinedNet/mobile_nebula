import MobileNebula
import NetworkExtension
import SwiftyJSON
import os.log

enum VPNStartError: Error {
  case noManagers
  case couldNotFindManager
  case noTunFileDescriptor
  case noProviderConfig
  case stoppedWhileStarting
}

enum AppMessageError: Error {
  case unknownIPCType(command: String)
}

extension AppMessageError: LocalizedError {
  public var description: String? {
    switch self {
    case .unknownIPCType(let command):
      return NSLocalizedString("Unknown IPC message type \(String(command))", comment: "")
    }
  }
}

class PacketTunnelProvider: NEPacketTunnelProvider {
  private var networkMonitor: NWPathMonitor?

  private var site: Site?
  private let log = Logger(subsystem: "net.defined.mobileNebula", category: "PacketTunnelProvider")
  private var nebula: MobileNebulaNebula?
  private var dnUpdater = DNUpdater()
  private var didSleep = false
  private var cachedRouteDescription: String?

  // A stopTunnel can race an in-flight start() before self.nebula exists, in
  // which case its nebula?.stop() is a silent no-op. Latch the stop here so
  // start() can apply it to the instance once it has been built. Never reset,
  // a provider instance serves one session, and if the system ever reused one
  // a stale latch refuses to start, which beats two nebulas on one tun fd.
  private var stopped = false
  private let stoppedLock = NSLock()

  // start() can be entered twice on one provider: an out of band boot runs it from
  // startTunnel, then the UI's connect flow sends the start IPC which runs it again.
  // Without a single flight guard the second pass builds a second nebula over the
  // same tun and orphans the first with its readers still running.
  private var starting = false

  private func isStopped() -> Bool {
    stoppedLock.lock()
    defer { stoppedLock.unlock() }
    return stopped
  }

  // beginStart reports whether this caller owns the start attempt. False means a
  // start is already in flight or has already succeeded, both are a no-op for the
  // second caller, the tunnel is up or on its way up.
  private func beginStart() -> Bool {
    stoppedLock.lock()
    defer { stoppedLock.unlock() }
    if starting || nebula != nil {
      return false
    }
    starting = true
    return true
  }

  // endStart clears the in flight flag. After a successful start the nebula check
  // in beginStart keeps later attempts out, after a failure the session is being
  // cancelled anyway.
  private func endStart() {
    stoppedLock.lock()
    defer { stoppedLock.unlock() }
    starting = false
  }

  // Latch the stop and halt the network monitor in one critical section so a
  // stop can't slip between start()'s latch check and its monitor startup.
  // Returns whether the latch was already set, so racing callers (stopTunnel
  // vs onExit) can tell who got there first.
  private func latchStopped() -> Bool {
    stoppedLock.lock()
    defer { stoppedLock.unlock() }
    let wasStopped = stopped
    stopped = true
    stopNetworkMonitor()
    return wasStopped
  }

  // Start the post startup work only if a stop has not raced us, atomic with
  // the stopped latch for the same reason as markStoppedAndHaltMonitor
  private func startPostStartWork() {
    stoppedLock.lock()
    defer { stoppedLock.unlock() }
    if stopped {
      return
    }
    startNetworkMonitor()
    dnUpdater.updateSingleLoop(site: site!, onUpdate: handleDNUpdate)
  }

  override func startTunnel(options: [String: NSObject]? = nil) async throws {
    // There is currently no way to get initialization errors back to the UI via completionHandler here
    // `expectStart` is sent only via the UI which means we should wait for the real start command which has another completion handler the UI can intercept
    if options?["expectStart"] != nil {
      // startTunnel must complete before IPC will work
      return
    }

    // VPN is being booted out of band of the UI. Use the system completion handler as there will be nothing to route initialization errors to but we still need to report
    // success/fail by the presence of an error or nil
    try await start()
  }

  private func start() async throws {
    guard beginStart() else {
      // Another start owns the tunnel bring up, or it is already up
      return
    }
    defer { endStart() }

    var manager: NETunnelProviderManager?
    var config: Data
    var key: String

    do {
      // Cannot use NETunnelProviderManager.loadAllFromPreferences() in earlier versions of iOS
      // TODO: Remove else once we drop support for iOS 16
      if ProcessInfo().isOperatingSystemAtLeast(
        OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0))
      {
        manager = try await self.findManager()
        guard let foundManager = manager else {
          throw VPNStartError.couldNotFindManager
        }
        self.site = try Site(manager: foundManager)
      } else {
        // This does not save the manager with the site, which means we cannot update the
        // vpn profile name when updates happen (rare).
        self.site = try Site(proto: self.protocolConfiguration as! NETunnelProviderProtocol)
      }
      config = self.site!.getConfig()
    } catch {
      //TODO: need a way to notify the app
      self.log.error("Failed to render config from vpn object")
      throw error
    }

    let _site = self.site!
    key = try _site.getKey()

    // This is set to 127.0.0.1 because it has to be something..
    let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

    // Set up all ipv4/6 networks and unsafe routes
    let (v4Settings, v6Settings) = try getNetworkAddressesAndRoutes(
      networks: _site.cert!.cert.networks,
      unsafeRoutes: _site.unsafeRoutes
    )

    if !_site.dnsResolvers.isEmpty {
      self.log.info("Assigning dns resolvers: \(_site.dnsResolvers, privacy: .public)")
      let dnsSettings = NEDNSSettings(servers: _site.dnsResolvers)
      if _site.matchDomains.isEmpty {
        // An empty string in matchDomains means "match all domains", which tells iOS to
        // actually route DNS queries through these servers. Without this, iOS ignores them.
        dnsSettings.matchDomains = [""]
      } else {
        dnsSettings.matchDomains = _site.matchDomains
      }
      if !_site.searchDomains.isEmpty {
        dnsSettings.searchDomains = _site.searchDomains
      }
      tunnelNetworkSettings.dnsSettings = dnsSettings
    }

    tunnelNetworkSettings.ipv4Settings = v4Settings
    tunnelNetworkSettings.ipv6Settings = v6Settings
    tunnelNetworkSettings.mtu = _site.mtu as NSNumber

    try await self.setTunnelNetworkSettings(tunnelNetworkSettings)

    // A stopTunnel that raced us across the awaits above may have already let
    // the session teardown invalidate and recycle the utun fd, bail before
    // scanning for it and handing it to Go
    if isStopped() {
      throw VPNStartError.stoppedWhileStarting
    }

    guard let fileDescriptor = self.tunnelFileDescriptor else {
      throw VPNStartError.noTunFileDescriptor
    }

    // Hand Go a dup so its descriptor stays valid even if a racing session
    // teardown closes and recycles the scanned fd number. Go closes the dup
    // during its own teardown, the session owns the original. Re-confirm the
    // dup is still the utun, if a stop closed and recycled the number between
    // the scan and here the dup would capture an unrelated descriptor.
    let dupFD = dup(fileDescriptor)
    guard dupFD >= 0, isUtunFd(dupFD) else {
      if dupFD >= 0 {
        close(dupFD)
      }
      throw VPNStartError.stoppedWhileStarting
    }
    let tunFD = Int(dupFD)

    var nebulaErr: NSError?
    self.nebula = MobileNebulaNewNebula(
      String(data: config, encoding: .utf8), key, self.site!.logFile, tunFD, &nebulaErr)

    if nebulaErr != nil {
      self.log.error("We had an error starting up: \(nebulaErr, privacy: .public)")
      throw nebulaErr!
    }

    // A stopTunnel that raced us before self.nebula existed had nothing to
    // stop, apply it to this instance so start(self) tears it back down
    if isStopped() {
      self.nebula?.stop()
    }

    try self.nebula!.start(self)

    // Skips the monitor and DN updater if a stopTunnel raced us, the tunnel
    // is coming down and nothing would ever cancel them
    startPostStartWork()
  }

  private func getNetworkAddressesAndRoutes(networks: [String], unsafeRoutes: [UnsafeRoute]) throws
    -> (NEIPv4Settings, NEIPv6Settings)
  {
    var err: NSError?
    var v4Addresses: [String] = []
    var v4Netmasks: [String] = []
    var v4Routes: [NEIPv4Route] = []

    var v6Addresses: [String] = []
    var v6PrefixLengths: [NSNumber] = []
    var v6Routes: [NEIPv6Route] = []

    for rawNetwork in networks {
      let network = MobileNebulaParseCIDR(rawNetwork, &err)
      if err != nil {
        throw err!
      }

      if network!.ipLen == 4 {
        v4Addresses.append(network!.address)
        v4Netmasks.append(network!.subnetMask)
        v4Routes.append(
          NEIPv4Route(
            destinationAddress: network!.maskedAddress,
            subnetMask: network!.subnetMask
          )
        )
      } else {
        v6Addresses.append(network!.address)
        v6PrefixLengths.append(network!.prefixLength as NSNumber)
        v6Routes.append(
          NEIPv6Route(
            destinationAddress: network!.maskedAddress,
            networkPrefixLength: network!.prefixLength as NSNumber
          )
        )
      }
    }

    for unsafeRoute in unsafeRoutes {
      let network = MobileNebulaParseCIDR(unsafeRoute.route, &err)
      if err != nil {
        throw err!
      }

      if network!.ipLen == 4 {
        v4Routes.append(
          NEIPv4Route(
            destinationAddress: network!.maskedAddress,
            subnetMask: network!.subnetMask
          )
        )
      } else {
        v6Routes.append(
          NEIPv6Route(
            destinationAddress: network!.maskedAddress,
            networkPrefixLength: network!.prefixLength as NSNumber
          )
        )
      }
    }

    let v4Settings = NEIPv4Settings(addresses: v4Addresses, subnetMasks: v4Netmasks)
    v4Settings.includedRoutes = v4Routes

    let v6Settings = NEIPv6Settings(addresses: v6Addresses, networkPrefixLengths: v6PrefixLengths)
    v6Settings.includedRoutes = v6Routes

    return (v4Settings, v6Settings)
  }

  private func handleDNUpdate(newSite: Site) {
    do {
      self.site = newSite
      try self.nebula?.reload(
        String(data: newSite.getConfig(), encoding: .utf8), key: newSite.getKey())

    } catch {
      log.error(
        "Got an error while updating nebula \(error.localizedDescription, privacy: .public)")
    }
  }

  //TODO: Sleep/wake get called aggressively and do nothing to help us here, we should locate why that is and make these work appropriately
  //    override func sleep(completionHandler: @escaping () -> Void) {
  //        nebula!.sleep()
  //        completionHandler()
  //    }

  private func findManager() async throws -> NETunnelProviderManager {
    let targetProtoConfig = self.protocolConfiguration as? NETunnelProviderProtocol
    guard let targetProviderConfig = targetProtoConfig?.providerConfiguration else {
      throw VPNStartError.noProviderConfig
    }
    let targetID = targetProviderConfig["id"] as? String

    // Load vpn configs from system, and find the manager matching the one being started
    let managers = try await NETunnelProviderManager.loadAllFromPreferences()
    for manager in managers {
      let mgrProtoConfig = manager.protocolConfiguration as? NETunnelProviderProtocol
      guard let mgrProviderConfig = mgrProtoConfig?.providerConfiguration else {
        throw VPNStartError.noProviderConfig
      }
      let id = mgrProviderConfig["id"] as? String
      if id == targetID {
        return manager
      }
    }

    // If we didn't find anything, throw an error
    throw VPNStartError.noManagers
  }

  private func startNetworkMonitor() {
    networkMonitor = NWPathMonitor()
    networkMonitor!.pathUpdateHandler = self.pathUpdate
    networkMonitor!.start(queue: DispatchQueue(label: "NetworkMonitor"))
  }

  private func stopNetworkMonitor() {
    self.networkMonitor?.cancel()
    networkMonitor = nil
  }

  override func stopTunnel(
    with reason: NEProviderStopReason, completionHandler: @escaping () -> Void
  ) {
    _ = latchStopped()

    // stop() blocks until the packet readers have drained and nebula has fully stopped
    nebula?.stop()
    completionHandler()
  }

  private func pathUpdate(path: Network.NWPath) {
    let routeDescription = collectAddresses(endpoints: path.gateways)
    if routeDescription != cachedRouteDescription {
      // Don't bother to rebind if we don't have any gateways
      if routeDescription != "" {
        nebula?.rebind(
          "network change to: \(routeDescription); from: \(cachedRouteDescription ?? "none")")
      }
      cachedRouteDescription = routeDescription
    }
  }

  private func collectAddresses(endpoints: [Network.NWEndpoint]) -> String {
    var str: [String] = []
    endpoints.forEach { endpoint in
      switch endpoint {
      case .hostPort(.ipv6(let host), let port):
        str.append("[\(host)]:\(port)")
      case .hostPort(.ipv4(let host), let port):
        str.append("\(host):\(port)")
      default:
        return
      }
    }

    return str.sorted().joined(separator: ", ")
  }

  override func handleAppMessage(_ data: Data) async -> Data? {
    guard let call = try? JSONDecoder().decode(IPCRequest.self, from: data) else {
      log.error("Failed to decode IPCRequest from network extension")
      return nil
    }

    var error: (any Error)?
    var data: JSON?

    // start command has special treatment due to needing to call two completers
    if call.command == "start" {
      do {
        try await self.start()
        // No response data, this is expected on a clean start
        return try? JSONEncoder().encode(IPCResponse.init(type: .success, message: nil))
      } catch {
        // A stop that raced this start already tore the tunnel down, either
        // cleanly or by yanking the session out from under one of the startup
        // steps. Report success so the user's own disconnect doesn't pop an
        // error in the UI, the site status will settle to disconnected via the
        // status stream. Log it in case the failure predated the stop.
        if isStopped() {
          log.error("Start failed while stopping: \(error.localizedDescription, privacy: .public)")
          return try? JSONEncoder().encode(IPCResponse.init(type: .success, message: nil))
        }
        defer {
          self.cancelTunnelWithError(error)
        }
        return try? JSONEncoder().encode(
          IPCResponse.init(type: .error, message: JSON(error.localizedDescription)))
      }
    }

    if nebula == nil {
      // Respond with an empty success message in the event a command comes in before we've truly started
      log.warning("Received command but do not have a nebula instance")
      return try? JSONEncoder().encode(IPCResponse.init(type: .success, message: nil))
    }

    //TODO: try catch over all this
    switch call.command {
    case "listHostmap": (data, error) = listHostmap(pending: false)
    case "listIndexes": (data, error) = listIndexes(pending: false)
    case "listPendingHostmap": (data, error) = listHostmap(pending: true)
    case "getHostInfo": (data, error) = getHostInfo(args: call.arguments!)
    case "setRemoteForTunnel": (data, error) = setRemoteForTunnel(args: call.arguments!)
    case "closeTunnel": (data, error) = closeTunnel(args: call.arguments!)

    default:
      error = AppMessageError.unknownIPCType(command: call.command)
    }

    if error != nil {
      return try? JSONEncoder().encode(
        IPCResponse.init(
          type: .error, message: JSON(error?.localizedDescription ?? "Unknown error")))
    } else {
      return try? JSONEncoder().encode(IPCResponse.init(type: .success, message: data))
    }
  }

  private func listHostmap(pending: Bool) -> (JSON?, (any Error)?) {
    var err: NSError?
    let res = nebula!.listHostmap(pending, error: &err)
    return (JSON(res), err)
  }

  private func listIndexes(pending: Bool) -> (JSON?, (any Error)?) {
    var err: NSError?
    let res = nebula!.listIndexes(pending, error: &err)
    return (JSON(res), err)
  }

  private func getHostInfo(args: JSON) -> (JSON?, (any Error)?) {
    var err: NSError?
    let res = nebula!.getHostInfo(
      byVpnIp: args["vpnIp"].string, pending: args["pending"].boolValue, error: &err)
    return (JSON(res), err)
  }

  private func setRemoteForTunnel(args: JSON) -> (JSON?, (any Error)?) {
    var err: NSError?
    let res = nebula!.setRemoteForTunnel(
      args["vpnIp"].string, addr: args["addr"].string, error: &err)
    return (JSON(res), err)
  }

  private func closeTunnel(args: JSON) -> (JSON?, (any Error)?) {
    let res = nebula!.closeTunnel(args["vpnIp"].string)
    return (JSON(res), nil)
  }

  // isUtunFd reports whether fd is a utun control socket, used both to find the
  // tun during startup and to re-confirm the dup we hand Go still points at it
  private func isUtunFd(_ fd: Int32) -> Bool {
    var ctlInfo = ctl_info()
    withUnsafeMutablePointer(to: &ctlInfo.ctl_name) {
      $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: $0.pointee)) {
        _ = strcpy($0, "com.apple.net.utun_control")
      }
    }
    if ioctl(fd, CTLIOCGINFO, &ctlInfo) != 0 {
      return false
    }

    var addr = sockaddr_ctl()
    var ret: Int32 = -1
    var len = socklen_t(MemoryLayout.size(ofValue: addr))
    withUnsafeMutablePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        ret = getpeername(fd, $0, &len)
      }
    }
    return ret == 0 && addr.sc_family == AF_SYSTEM && addr.sc_id == ctlInfo.ctl_id
  }

  private var tunnelFileDescriptor: Int32? {
    for fd: Int32 in 0...1024 {
      if isUtunFd(fd) {
        return fd
      }
    }
    return nil
  }
}

extension PacketTunnelProvider: MobileNebulaExitCallbackProtocol {
  // Called from a Go thread when nebula dies on its own, e.g. a fatal packet
  // reader error, so the tunnel comes down instead of blackholing traffic
  func onExit(_ message: String?) {
    // Latch the stop and halt the monitor ourselves, stopTunnel may be a long
    // time coming after a self death and nothing should poke the dead nebula
    // meanwhile. If the latch was already set this death belongs to a
    // requested stop, don't report the user's own disconnect as a failure.
    if latchStopped() {
      return
    }

    let error = message ?? "Nebula exited unexpectedly"
    log.error("\(error, privacy: .public)")
    cancelTunnelWithError(
      NSError(
        domain: "net.defined.mobileNebula", code: 1,
        userInfo: [NSLocalizedDescriptionKey: error]))
  }
}
