import MobileNebula
import NetworkExtension

class SiteContainer {
    var site: Site
    var updater: SiteUpdater

    init(site: Site, updater: SiteUpdater) {
        self.site = site
        self.updater = updater
    }
}

class Sites {
    private var containers = [String: SiteContainer]()
    private var messenger: (any FlutterBinaryMessenger)?

    init(messenger: (any FlutterBinaryMessenger)?) {
        self.messenger = messenger
    }

    func loadSites(completion: @escaping ([String: Site]?, (any Error)?) -> Void) {
        _ = SiteList { sites, err in
            if err != nil {
                return completion(nil, err)
            }

            sites?.values.forEach { site in
                var updater = self.containers[site.id]?.updater
                if updater != nil {
                    updater!.setSite(site: site)
                } else {
                    updater = SiteUpdater(messenger: self.messenger!, site: site)
                }
                self.containers[site.id] = SiteContainer(site: site, updater: updater!)
            }

            let justSites = self.containers.mapValues {
                $0.site
            }
            completion(justSites, nil)
        }
    }

    func deleteSite(id: String, callback: @escaping ((any Error)?) -> Void) {
        if let site = containers.removeValue(forKey: id) {
            _ = KeyChain.delete(key: "\(site.site.id).dnCredentials")
            _ = KeyChain.delete(key: "\(site.site.id).key")

            do {
                let fileManager = FileManager.default
                let siteDir = try SiteList.getSiteDir(id: site.site.id)
                try fileManager.removeItem(at: siteDir)
            } catch {
                print("Failed to delete site from fs: \(error.localizedDescription)")
            }

            #if !targetEnvironment(simulator)
                site.site.manager!.removeFromPreferences(completionHandler: callback)
                return
            #endif
        }

        // Nothing to remove
        callback(nil)
    }

    func getSite(id: String) -> Site? {
        return containers[id]?.site
    }

    func getUpdater(id: String) -> SiteUpdater? {
        return containers[id]?.updater
    }

    func getContainer(id: String) -> SiteContainer? {
        return containers[id]
    }
}

class SiteUpdater: NSObject, FlutterStreamHandler, @unchecked Sendable {
    private var eventSink: FlutterEventSink?
    private var eventChannel: FlutterEventChannel
    private var site: Site
    private var notification: Any?
    public var startFunc: (() -> Void)?
    private var configFd: Int32? = nil
    private var configObserver: (any DispatchSourceFileSystemObject)? = nil

    init(messenger: any FlutterBinaryMessenger, site: Site) {
        do {
            let configPath = try SiteList.getSiteConfigFile(id: site.id, createDir: false)
            configFd = open(configPath.path, O_EVTONLY)
            configObserver = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: configFd!,
                eventMask: .write
            )

        } catch {
            // SiteList.getSiteConfigFile should never throw because we are not creating it here
            configObserver = nil
        }

        eventChannel = FlutterEventChannel(name: "net.defined.nebula/\(site.id)", binaryMessenger: messenger)
        self.site = site
        super.init()

        eventChannel.setStreamHandler(self)

        configObserver?.setEventHandler(handler: configUpdated)
        configObserver?.setCancelHandler {
            if self.configFd != nil {
                close(self.configFd!)
            }
            self.configObserver = nil
        }

        configObserver?.resume()
    }

    func setSite(site: Site) {
        self.site = site
    }

    /// onListen is called when flutter code attaches an event listener
    func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events

        #if !targetEnvironment(simulator)
            if site.manager == nil {
                // TODO: The dn updater path seems to race to build a site that lacks a manager. The UI does not display this error
                // and a another listen should occur and succeed.
                return FlutterError(code: "Internal Error", message: "Flutter manager was not present", details: nil)
            }

            notification = NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: site.manager!.connection, queue: nil) { _ in
                let oldConnected = self.site.connected
                self.site.status = statusString[self.site.manager!.connection.status]
                self.site.connected = statusMap[self.site.manager!.connection.status]

                // Check to see if we just moved to connected and if we have a start function to call when that happens
                if self.site.connected!, oldConnected != self.site.connected, self.startFunc != nil {
                    self.startFunc!()
                    self.startFunc = nil
                }

                self.update(connected: self.site.connected!)
            }
        #endif
        return nil
    }

    /// onCancel is called when the flutter listener stops listening
    func onCancel(withArguments _: Any?) -> FlutterError? {
        if notification != nil {
            NotificationCenter.default.removeObserver(notification!)
        }
        return nil
    }

    /// update is a way to send information to the flutter listener and generally should not be used directly
    func update(connected: Bool, replaceSite: Site? = nil) {
        if replaceSite != nil {
            site = replaceSite!
        }
        site.connected = connected
        site.status = connected ? "Connected" : "Disconnected"

        let encoder = JSONEncoder()
        let data = try! encoder.encode(site)
        eventSink?(String(data: data, encoding: .utf8))
    }

    private func configUpdated() {
        if site.connected != true {
            return
        }

        guard let newSite = try? Site(manager: site.manager!) else {
            return
        }

        update(connected: newSite.connected ?? false, replaceSite: newSite)
    }
}
