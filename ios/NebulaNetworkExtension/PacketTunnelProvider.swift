import NetworkExtension
import MobileNebula
import os.log
import MMWormhole

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var networkMonitor: NWPathMonitor?
    private var ifname: String?
    
    private var site: Site?
    private var _log = OSLog(subsystem: "net.defined.mobileNebula", category: "PacketTunnelProvider")
    private var wormhole = MMWormhole(applicationGroupIdentifier: "group.net.defined.mobileNebula", optionalDirectory: "ipc")
    private var nebula: MobileNebulaNebula?
    private var didSleep = false
    
    private func log(_ message: StaticString, _ args: CVarArg...) {
        os_log(message, log: _log, args)
    }
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        NSKeyedUnarchiver.setClass(IPCRequest.classForKeyedUnarchiver(), forClassName: "Runner.IPCRequest")
        let proto = self.protocolConfiguration as! NETunnelProviderProtocol
        var config: Data
        var key: String

        do {
            config = proto.providerConfiguration?["config"] as! Data
            site = try Site(proto: proto)
        } catch {
            //TODO: need a way to notify the app
            log("Failed to render config from vpn object")
            return completionHandler(error)
        }
        
        let _site = site!
        _log = OSLog(subsystem: "net.defined.mobileNebula:\(_site.name)", category: "PacketTunnelProvider")
        
        do {
            key = try _site.getKey()
        } catch {
            wormhole.passMessageObject(IPCMessage(id: _site.id, type: "error", message: error.localizedDescription), identifier: "nebula")
            return completionHandler(error)
        }
        
        startNetworkMonitor()
        
        let fileDescriptor = (self.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32) ?? -1
        if fileDescriptor < 0 {
            let msg = IPCMessage(id: _site.id, type: "error", message: "Starting tunnel failed: Could not determine file descriptor")
            wormhole.passMessageObject(msg, identifier: "nebula")
            return completionHandler(NSError())
        }

        var ifnameSize = socklen_t(IFNAMSIZ)
        let ifnamePtr = UnsafeMutablePointer<CChar>.allocate(capacity: Int(ifnameSize))
        ifnamePtr.initialize(repeating: 0, count: Int(ifnameSize))
        if getsockopt(fileDescriptor, 2 /* SYSPROTO_CONTROL */, 2 /* UTUN_OPT_IFNAME */, ifnamePtr, &ifnameSize) == 0 {
            self.ifname = String(cString: ifnamePtr)
        }
        ifnamePtr.deallocate()

        // This is set to 127.0.0.1 because it has to be something..
        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        // Make sure our ip is routed to the tun device
        var err: NSError?
        let ipNet = MobileNebulaParseCIDR(_site.cert!.cert.details.ips[0], &err)
        if (err != nil) {
            let msg = IPCMessage(id: _site.id, type: "error", message: err?.localizedDescription ?? "Unknown error from go MobileNebula.ParseCIDR - certificate")
            self.wormhole.passMessageObject(msg, identifier: "nebula")
            return completionHandler(err)
        }
        tunnelNetworkSettings.ipv4Settings = NEIPv4Settings(addresses: [ipNet!.ip], subnetMasks: [ipNet!.maskCIDR])
        var routes: [NEIPv4Route] = [NEIPv4Route(destinationAddress: ipNet!.network, subnetMask: ipNet!.maskCIDR)]
        
        // Add our unsafe routes
        _site.unsafeRoutes.forEach { unsafeRoute in
            let ipNet = MobileNebulaParseCIDR(unsafeRoute.route, &err)
            if (err != nil) {
                let msg = IPCMessage(id: _site.id, type: "error", message: err?.localizedDescription ?? "Unknown error from go MobileNebula.ParseCIDR - unsafe routes")
                self.wormhole.passMessageObject(msg, identifier: "nebula")
                return completionHandler(err)
            }
            routes.append(NEIPv4Route(destinationAddress: ipNet!.network, subnetMask: ipNet!.maskCIDR))
        }
        
        tunnelNetworkSettings.ipv4Settings!.includedRoutes = routes
        tunnelNetworkSettings.mtu = _site.mtu as NSNumber

        wormhole.listenForMessage(withIdentifier: "app", listener: self.wormholeListener)
        self.setTunnelNetworkSettings(tunnelNetworkSettings, completionHandler: {(error:Error?) in
            if (error != nil) {
                let msg = IPCMessage(id: _site.id, type: "error", message: error?.localizedDescription ?? "Unknown setTunnelNetworkSettings error")
                self.wormhole.passMessageObject(msg, identifier: "nebula")
                return completionHandler(error)
            }
            
            var err: NSError?
            self.nebula = MobileNebulaNewNebula(String(data: config, encoding: .utf8), key, self.site!.logFile, Int(fileDescriptor), &err)
            if err != nil {
                let msg = IPCMessage(id: _site.id, type: "error", message: err?.localizedDescription ?? "Unknown error from go MobileNebula.Main")
                self.wormhole.passMessageObject(msg, identifier: "nebula")
                return completionHandler(err)
            }
            
            self.nebula!.start()
            completionHandler(nil)
        })
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        nebula!.sleep()
        completionHandler()
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
        //TODO: we can likely be smarter here and enumerate all the interfaces and their current addresses, only rebind if things changed
        nebula?.rebind("network change")
    }
    
    private func wormholeListener(msg: Any?) {
        guard let call = msg as? IPCRequest else {
            log("Failed to decode IPCRequest from network extension")
            return
        }
        
        var error: Error?
        var data: Any?
        
        //TODO: try catch over all this
        switch call.type {
        case "listHostmap": (data, error) = listHostmap(pending: false)
        case "listPendingHostmap": (data, error) = listHostmap(pending: true)
        case "getHostInfo": (data, error) = getHostInfo(args: call.arguments!)
        case "setRemoteForTunnel": (data, error) = setRemoteForTunnel(args: call.arguments!)
        case "closeTunnel": (data, error) = closeTunnel(args: call.arguments!)
            
        default:
            error = "Unknown IPC message type \(call.type)"
        }
        
        if (error != nil) {
            self.wormhole.passMessageObject(IPCMessage(id: "", type: "error", message: error!.localizedDescription), identifier: call.callbackId)
        } else {
            self.wormhole.passMessageObject(IPCMessage(id: "", type: "success", message: data), identifier: call.callbackId)
        }
    }
    
    private func listHostmap(pending: Bool) -> (String?, Error?) {
        var err: NSError?
        let res = nebula!.listHostmap(pending, error: &err)
        return (res, err)
    }
    
    private func getHostInfo(args: Dictionary<String, Any>) -> (String?, Error?) {
        var err: NSError?
        let res = nebula!.getHostInfo(byVpnIp: args["vpnIp"] as? String, pending: args["pending"] as! Bool, error: &err)
        return (res, err)
    }
    
    private func setRemoteForTunnel(args: Dictionary<String, Any>) -> (String?, Error?) {
        var err: NSError?
        let res = nebula!.setRemoteForTunnel(args["vpnIp"] as? String, addr: args["addr"] as? String, error: &err)
        return (res, err)
    }
    
    private func closeTunnel(args: Dictionary<String, Any>) -> (Bool?, Error?) {
        let res = nebula!.closeTunnel(args["vpnIp"] as? String)
        return (res, nil)
    }
}

