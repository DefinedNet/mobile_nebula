import NetworkExtension

class SiteList {
    private var sites = [String: Site]()
    
    /// Gets the root directory that can be used to share files between the UI and VPN process. Does ensure the directory exists
    static func getRootDir() throws -> URL {
        let fileManager = FileManager.default
        let rootDir = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.net.defined.mobileNebula")!
        
        if (!fileManager.fileExists(atPath: rootDir.absoluteString)) {
            try fileManager.createDirectory(at: rootDir, withIntermediateDirectories: true)
        }
        
        return rootDir
    }
    
    /// Gets the directory where all sites live, $rootDir/sites. Does ensure the directory exists
    static func getSitesDir() throws -> URL {
        let fileManager = FileManager.default
        let sitesDir = try getRootDir().appendingPathComponent("sites", isDirectory: true)
        if (!fileManager.fileExists(atPath: sitesDir.absoluteString)) {
            try fileManager.createDirectory(at: sitesDir, withIntermediateDirectories: true)
        }
        return sitesDir
    }
    
    /// Gets the directory where a single site would live, $rootDir/sites/$siteID
    static func getSiteDir(id: String, create: Bool = false) throws -> URL {
        let fileManager = FileManager.default
        let siteDir = try getSitesDir().appendingPathComponent(id, isDirectory: true)
        if (create && !fileManager.fileExists(atPath: siteDir.absoluteString)) {
            try fileManager.createDirectory(at: siteDir, withIntermediateDirectories: true)
        }
        return siteDir
    }
    
    /// Gets the file that represents the site configuration, $rootDir/sites/$siteID/config.json
    static func getSiteConfigFile(id: String, createDir: Bool) throws -> URL {
        return try getSiteDir(id: id, create: createDir).appendingPathComponent("config", isDirectory: false).appendingPathExtension("json")
    }
    
    /// Gets the file that represents the site log output, $rootDir/sites/$siteID/log
    static func getSiteLogFile(id: String, createDir: Bool) throws -> URL {
        return try getSiteDir(id: id, create: createDir).appendingPathComponent("logs", isDirectory: false)
    }
    
    init(completion: @escaping ([String: Site]?, Error?) -> ()) {
#if targetEnvironment(simulator)
        SiteList.loadAllFromFS { sites, err in
            if sites != nil {
                self.sites = sites!
            }
            completion(sites, err)
        }
#else
        SiteList.loadAllFromNETPM { sites, err in
            if sites != nil {
                self.sites = sites!
            }
            completion(sites, err)
        }
#endif
    }
    
    private static func loadAllFromFS(completion: @escaping ([String: Site]?, Error?) -> ()) {
        let fileManager = FileManager.default
        var siteDirs: [URL]
        var sites = [String: Site]()
        
        do {
            siteDirs = try fileManager.contentsOfDirectory(at: getSitesDir(), includingPropertiesForKeys: nil)
            
        } catch {
            completion(nil, error)
            return
        }
        
        siteDirs.forEach { path in
            do {
                let site = try Site(path: path.appendingPathComponent("config").appendingPathExtension("json"))
                sites[site.id] = site
                
            } catch {
                print(error)
                try? fileManager.removeItem(at: path)
                print("Deleted non conforming site \(path)")
            }
        }
        
        completion(sites, nil)
    }
    
    private static func loadAllFromNETPM(completion: @escaping ([String: Site]?, Error?) -> ()) {
        var sites = [String: Site]()
        
        // dispatchGroup is used to ensure we have migrated all sites before returning them
        // If there are no sites to migrate, there are never any entrants
        let dispatchGroup = DispatchGroup()
        
        NETunnelProviderManager.loadAllFromPreferences() { newManagers, err in
            if (err != nil) {
                return completion(nil, err)
            }
            
            newManagers?.forEach { manager in
                do {
                    let site = try Site(manager: manager)
                    if site.needsToMigrateToFS {
                        dispatchGroup.enter()
                        site.incomingSite?.save(manager: manager) { error in
                            if error != nil {
                                print("Error while migrating site to fs: \(error!.localizedDescription)")
                            }
                            
                            print("Migrated site to fs: \(site.name)")
                            site.needsToMigrateToFS = false
                            dispatchGroup.leave()
                        }
                    }
                    sites[site.id] = site
                    
                } catch {
                    //TODO: notify the user about this
                    print("Deleted non conforming site \(manager) \(error)")
                    manager.removeFromPreferences()
                    //TODO: delete from disk, we need to try and discover the site id though
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion(sites, nil)
            }
        }
    }
    
    func getSites() -> [String: Site] {
        return sites
    }
}
