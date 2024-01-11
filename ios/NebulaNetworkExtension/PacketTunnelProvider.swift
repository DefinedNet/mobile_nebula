import NetworkExtension
import MobileNebula
import os.log
import SwiftyJSON

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var networkMonitor: NWPathMonitor?
    
    private var site: Site?
    private var log = Logger(subsystem: "net.defined.mobileNebula", category: "PacketTunnelProvider")
    private var nebula: MobileNebulaNebula?
    private var dnUpdater = DNUpdater()
    private var didSleep = false
    private var cachedRouteDescription: String?
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // There is currently no way to get initialization errors back to the UI via completionHandler here
        // `expectStart` is sent only via the UI which means we should wait for the real start command which has another completion handler the UI can intercept
        if options?["expectStart"] != nil {
            // The system completion handler must be called before IPC will work
            completionHandler(nil)
            return
        }
        
        // VPN is being booted out of band of the UI. Use the system completion handler as there will be nothing to route initialization errors to but we still need to report
        // success/fail by the presence of an error or nil
        start(completionHandler: completionHandler)
    }
    
    private func start(completionHandler: @escaping (Error?) -> Void) {
        let proto = self.protocolConfiguration as! NETunnelProviderProtocol
        var config: Data
        var key: String

        do {
            site = try Site(proto: proto)
            config = try site!.getConfig()
        } catch {
            //TODO: need a way to notify the app
            log.error("Failed to render config from vpn object")
            return completionHandler(error)
        }

        let _site = site!

        do {
            key = try _site.getKey()
        } catch {
            return completionHandler(error)
        }
        
        let fileDescriptor = tunnelFileDescriptor
        if fileDescriptor == nil {
            return completionHandler("Unable to locate the tun file descriptor")
        }
        let tunFD = Int(fileDescriptor!)

        // This is set to 127.0.0.1 because it has to be something..
        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        // Make sure our ip is routed to the tun device
        var err: NSError?
        let ipNet = MobileNebulaParseCIDR(_site.cert!.cert.details.ips[0], &err)
        if (err != nil) {
            return completionHandler(err!)
        }
        tunnelNetworkSettings.ipv4Settings = NEIPv4Settings(addresses: [ipNet!.ip], subnetMasks: [ipNet!.maskCIDR])
        var routes: [NEIPv4Route] = [NEIPv4Route(destinationAddress: ipNet!.network, subnetMask: ipNet!.maskCIDR)]

        // Add our unsafe routes
        _site.unsafeRoutes.forEach { unsafeRoute in
            let ipNet = MobileNebulaParseCIDR(unsafeRoute.route, &err)
            if (err != nil) {
                return completionHandler(err!)
            }
            routes.append(NEIPv4Route(destinationAddress: ipNet!.network, subnetMask: ipNet!.maskCIDR))
        }

        tunnelNetworkSettings.ipv4Settings!.includedRoutes = routes
        tunnelNetworkSettings.mtu = _site.mtu as NSNumber

        if !_site.dnsResolvers.isEmpty {
            let dnsSettings = NEDNSSettings(servers: _site.dnsResolvers)
            
            tunnelNetworkSettings.dnsSettings = dnsSettings
        }
        self.setTunnelNetworkSettings(tunnelNetworkSettings, completionHandler: {(error:Error?) in
            if (error != nil) {
                return completionHandler(error!)
            }

            var err: NSError?
            self.nebula = MobileNebulaNewNebula(String(data: config, encoding: .utf8), key, self.site!.logFile, tunFD, &err)
            self.startNetworkMonitor()

            if err != nil {
                self.log.error("We had an error starting up: \(err, privacy: .public)")
                return completionHandler(err!)
            }
            
            self.nebula!.start()
            self.dnUpdater.updateSingleLoop(site: self.site!, onUpdate: self.handleDNUpdate)
            
            completionHandler(nil)
        })
    }
    
    private func handleDNUpdate(newSite: Site) {
        do {
            self.site = newSite
            try self.nebula?.reload(String(data: newSite.getConfig(), encoding: .utf8), key: newSite.getKey())
            
        } catch {
            self.log.error("Got an error while updating nebula \(error.localizedDescription, privacy: .public)")
        }
    }
    
//TODO: Sleep/wake get called aggressively and do nothing to help us here, we should locate why that is and make these work appropriately
//    override func sleep(completionHandler: @escaping () -> Void) {
//        nebula!.sleep()
//        completionHandler()
//    }
    
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
    
    override func handleAppMessage(_ data: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard let call = try? JSONDecoder().decode(IPCRequest.self, from: data) else {
            log.error("Failed to decode IPCRequest from network extension")
            return
        }
        
        var error: Error?
        var data: JSON?
        
        // start command has special treatment due to needing to call two completers
        if call.command == "start" {
            self.start() { error in
                // Notify the UI if we have a completionHandler
                if completionHandler != nil {
                    if error == nil {
                        // No response data, this is expected on a clean start
                        completionHandler!(try? JSONEncoder().encode(IPCResponse.init(type: .success, message: nil)))
                        
                    } else {
                        // We failed, notify and shutdown
                        completionHandler!(try? JSONEncoder().encode(IPCResponse.init(type: .error, message: JSON(error!.localizedDescription))))
                        self.cancelTunnelWithError(error)
                    }
                }
            }
            return
        }
        
        if nebula == nil {
            // Respond with an empty success message in the event a command comes in before we've truly started
            log.warning("Received command but do not have a nebula instance")
            return completionHandler!(try? JSONEncoder().encode(IPCResponse.init(type: .success, message: nil)))
        }
        
        //TODO: try catch over all this
        switch call.command {
        case "listHostmap": (data, error) = listHostmap(pending: false)
        case "listPendingHostmap": (data, error) = listHostmap(pending: true)
        case "getHostInfo": (data, error) = getHostInfo(args: call.arguments!)
        case "setRemoteForTunnel": (data, error) = setRemoteForTunnel(args: call.arguments!)
        case "closeTunnel": (data, error) = closeTunnel(args: call.arguments!)
            
        default:
            error = "Unknown IPC message type \(call.command)"
        }
        
        if (error != nil) {
            completionHandler!(try? JSONEncoder().encode(IPCResponse.init(type: .error, message: JSON(error?.localizedDescription ?? "Unknown error"))))
        } else {
            completionHandler!(try? JSONEncoder().encode(IPCResponse.init(type: .success, message: data)))
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

