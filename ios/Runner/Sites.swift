import NetworkExtension
import MobileNebula

class SiteContainer {
    var site: Site
    var updater: SiteUpdater
    
    init(site: Site, updater: SiteUpdater) {
        self.site = site
        self.updater = updater
    }
}

class Sites {
    private var sites = [String: SiteContainer]()
    private var messenger: FlutterBinaryMessenger?
    
    init(messenger: FlutterBinaryMessenger?) {
        self.messenger = messenger
    }

    func loadSites(completion: @escaping ([String: Site]?, Error?) -> ()) {
#if targetEnvironment(simulator)
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("sites")
        var configPaths: [URL]
        
        do {
            if (!fileManager.fileExists(atPath: documentsURL.absoluteString)) {
                try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            }
            configPaths = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
        } catch {
            return completion(nil, error)
        }
        
        configPaths.forEach { path in
            do {
                let config = try Data(contentsOf: path)
                let decoder = JSONDecoder()
                let incoming = try decoder.decode(IncomingSite.self, from: config)
                let site = try Site(incoming: incoming)
                let updater = SiteUpdater(messenger: self.messenger!, site: site)
                self.sites[site.id] = SiteContainer(site: site, updater: updater)
            } catch {
                print(error)
               // try? fileManager.removeItem(at: path)
                print("Deleted non conforming site \(path)")
            }
        }
        
        let justSites = self.sites.mapValues {
            return $0.site
        }
        completion(justSites, nil)
        
#else
        NETunnelProviderManager.loadAllFromPreferences() { newManagers, err in
            if (err != nil) {
                return completion(nil, err)
            }

            newManagers?.forEach { manager in
                do {
                    let site = try Site(manager: manager)
                    // Load the private key to make sure we can
                    _ = try site.getKey()
                    let updater = SiteUpdater(messenger: self.messenger!, site: site)
                    self.sites[site.id] = SiteContainer(site: site, updater: updater)
                } catch {
                    //TODO: notify the user about this
                    print("Deleted non conforming site \(manager) \(error)")
                    manager.removeFromPreferences()
                }
            }
            
            let justSites = self.sites.mapValues {
                return $0.site
            }
            completion(justSites, nil)
        }
#endif
    }
    
    func deleteSite(id: String, callback: @escaping (Error?) -> ()) {
        if let site = self.sites.removeValue(forKey: id) {
#if targetEnvironment(simulator)
            let fileManager = FileManager.default
            let sitePath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("sites").appendingPathComponent(site.site.id)
            try? fileManager.removeItem(at: sitePath)
#else
            _ = KeyChain.delete(key: site.site.id)
            site.site.manager!.removeFromPreferences(completionHandler: callback)
#endif
        }
        
        // Nothing to remove
        callback(nil)
    }
    
    func getSite(id: String) -> Site? {
        return self.sites[id]?.site
    }
    
    func getUpdater(id: String) -> SiteUpdater? {
        return self.sites[id]?.updater
    }
    
    func getContainer(id: String) -> SiteContainer? {
        return self.sites[id]
    }
}

class SiteUpdater: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?;
    private var eventChannel: FlutterEventChannel;
    private var site: Site
    private var notification: Any?
    public var startFunc: (() -> Void)?
    
    init(messenger: FlutterBinaryMessenger, site: Site) {
        eventChannel = FlutterEventChannel(name: "net.defined.nebula/\(site.id)", binaryMessenger: messenger)
        self.site = site
        super.init()
        eventChannel.setStreamHandler(self)
    }
    
    /// onListen is called when flutter code attaches an event listener
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events;

        self.notification = NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: site.manager!.connection , queue: nil) { n in
            let connected = self.site.connected
            self.site.status = statusString[self.site.manager!.connection.status]
            self.site.connected = statusMap[self.site.manager!.connection.status]
            
            // Check to see if we just moved to connected and if we have a start function to call when that happens
            if self.site.connected! && connected != self.site.connected && self.startFunc != nil {
                self.startFunc!()
                self.startFunc = nil
            }
            
            let d: Dictionary<String, Any> = [
                "connected": self.site.connected!,
                "status": self.site.status!,
            ]
            self.eventSink?(d)
        }
        
        return nil
    }

    /// onCancel is called when the flutter listener stops listening
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if (self.notification != nil) {
            NotificationCenter.default.removeObserver(self.notification!)
        }
        return nil
    }
    
    /// update is a way to send information to the flutter listener and generally should not be used directly
    func update(connected: Bool) {
        let d: Dictionary<String, Any> = [
            "connected": connected,
            "status": connected ? "Connected" : "Disconnected",
        ]
        self.eventSink?(d)
    }
}
