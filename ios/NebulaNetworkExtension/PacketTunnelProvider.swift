import NetworkExtension
import MobileNebula
import os.log
import SwiftyJSON

enum VPNStartError: Error {
    case noManagers
    case couldNotFindManager
    case noTunFileDescriptor
    case noProviderConfig
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
    
    override func startTunnel(options: [String : NSObject]? = nil) async throws {
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
        var manager: NETunnelProviderManager?
        var config: Data
        var key: String
        
        manager = try await self.findManager()
        
        guard let foundManager = manager else {
            throw VPNStartError.couldNotFindManager
        }
        
        do {
            self.site = try Site(manager: foundManager)
            config = try self.site!.getConfig()
        } catch {
            //TODO: need a way to notify the app
            self.log.error("Failed to render config from vpn object")
            throw error
        }

        let _site = self.site!
        key = try _site.getKey()
        
        guard let fileDescriptor = self.tunnelFileDescriptor else {
            throw VPNStartError.noTunFileDescriptor
        }
        let tunFD = Int(fileDescriptor)

        // This is set to 127.0.0.1 because it has to be something..
        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        // Make sure our ip is routed to the tun device
        var err: NSError?
        let ipNet = MobileNebulaParseCIDR(_site.cert!.cert.details.ips[0], &err)
        if (err != nil) {
            throw err!
        }
        tunnelNetworkSettings.ipv4Settings = NEIPv4Settings(addresses: [ipNet!.ip], subnetMasks: [ipNet!.maskCIDR])
        var routes: [NEIPv4Route] = [NEIPv4Route(destinationAddress: ipNet!.network, subnetMask: ipNet!.maskCIDR)]

        // Add our unsafe routes
        try _site.unsafeRoutes.forEach { unsafeRoute in
            let ipNet = MobileNebulaParseCIDR(unsafeRoute.route, &err)
            if (err != nil) {
                throw err!
            }
            routes.append(NEIPv4Route(destinationAddress: ipNet!.network, subnetMask: ipNet!.maskCIDR))
        }

        tunnelNetworkSettings.ipv4Settings!.includedRoutes = routes
        tunnelNetworkSettings.mtu = _site.mtu as NSNumber

        try await self.setTunnelNetworkSettings(tunnelNetworkSettings)
        var nebulaErr: NSError?
        self.nebula = MobileNebulaNewNebula(String(data: config, encoding: .utf8), key, self.site!.logFile, tunFD, &nebulaErr)
        self.startNetworkMonitor()

        if nebulaErr != nil {
            self.log.error("We had an error starting up: \(nebulaErr, privacy: .public)")
            throw nebulaErr!
        }
        
        self.nebula!.start()
        self.dnUpdater.updateSingleLoop(site: self.site!, onUpdate: self.handleDNUpdate)
    }
    
    private func handleDNUpdate(newSite: Site) {
        do {
            self.site = newSite
            try self.nebula?.reload(String(data: newSite.getConfig(), encoding: .utf8), key: newSite.getKey())
            
        } catch {
            log.error("Got an error while updating nebula \(error.localizedDescription, privacy: .public)")
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
            if (id == targetID) {
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
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        nebula?.stop()
        stopNetworkMonitor()
        completionHandler()
    }
        
    private func pathUpdate(path: Network.NWPath) {
        let routeDescription = collectAddresses(endpoints: path.gateways)
        if routeDescription != cachedRouteDescription {
            // Don't bother to rebind if we don't have any gateways
            if routeDescription != "" {
                nebula?.rebind("network change to: \(routeDescription); from: \(cachedRouteDescription ?? "none")")
            }
            cachedRouteDescription = routeDescription
        }
    }
    
    private func collectAddresses(endpoints: [Network.NWEndpoint]) -> String {
        var str: [String] = []
        endpoints.forEach{ endpoint in
            switch endpoint {
            case let .hostPort(.ipv6(host), port):
                str.append("[\(host)]:\(port)")
            case let .hostPort(.ipv4(host), port):
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
        
        var error: Error?
        var data: JSON?
        
        // start command has special treatment due to needing to call two completers
        if call.command == "start" {
            do {
                try await self.start()
                // No response data, this is expected on a clean start
                return try? JSONEncoder().encode(IPCResponse.init(type: .success, message: nil))
            } catch {
                defer {
                    self.cancelTunnelWithError(error)
                }
                return try? JSONEncoder().encode(IPCResponse.init(type: .error, message: JSON(error.localizedDescription)))
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
        case "listPendingHostmap": (data, error) = listHostmap(pending: true)
        case "getHostInfo": (data, error) = getHostInfo(args: call.arguments!)
        case "setRemoteForTunnel": (data, error) = setRemoteForTunnel(args: call.arguments!)
        case "closeTunnel": (data, error) = closeTunnel(args: call.arguments!)
            
        default:
            error = AppMessageError.unknownIPCType(command: call.command)
        }
        
        if (error != nil) {
            return try? JSONEncoder().encode(IPCResponse.init(type: .error, message: JSON(error?.localizedDescription ?? "Unknown error")))
        } else {
            return try? JSONEncoder().encode(IPCResponse.init(type: .success, message: data))
        }
    }
    
    private func listHostmap(pending: Bool) -> (JSON?, Error?) {
        var err: NSError?
        let res = nebula!.listHostmap(pending, error: &err)
        return (JSON(res), err)
    }
    
    private func getHostInfo(args: JSON) -> (JSON?, Error?) {
        var err: NSError?
        let res = nebula!.getHostInfo(byVpnIp: args["vpnIp"].string, pending: args["pending"].boolValue, error: &err)
        return (JSON(res), err)
    }
    
    private func setRemoteForTunnel(args: JSON) -> (JSON?, Error?) {
        var err: NSError?
        let res = nebula!.setRemoteForTunnel(args["vpnIp"].string, addr: args["addr"].string, error: &err)
        return (JSON(res), err)
    }
    
    private func closeTunnel(args: JSON) -> (JSON?, Error?) {
        let res = nebula!.closeTunnel(args["vpnIp"].string)
        return (JSON(res), nil)
    }
    
    private var tunnelFileDescriptor: Int32? {
        var ctlInfo = ctl_info()
        withUnsafeMutablePointer(to: &ctlInfo.ctl_name) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: $0.pointee)) {
                _ = strcpy($0, "com.apple.net.utun_control")
            }
        }
        for fd: Int32 in 0...1024 {
            var addr = sockaddr_ctl()
            var ret: Int32 = -1
            var len = socklen_t(MemoryLayout.size(ofValue: addr))
            withUnsafeMutablePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    ret = getpeername(fd, $0, &len)
                }
            }
            if ret != 0 || addr.sc_family != AF_SYSTEM {
                continue
            }
            if ctlInfo.ctl_id == 0 {
                ret = ioctl(fd, CTLIOCGINFO, &ctlInfo)
                if ret != 0 {
                    continue
                }
            }
            if addr.sc_id == ctlInfo.ctl_id {
                return fd
            }
        }
        return nil
    }
}

