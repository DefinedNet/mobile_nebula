import NetworkExtension

typealias SiteDictionary = [String: Site]

actor SiteList {
  // This keeps a reference around to the sites that are loaded. It's not referenced elsewhere.
  private var sites = SiteDictionary()

  /// Gets the root directory that can be used to share files between the UI and VPN process. Does ensure the directory exists
  static func getRootDir() throws -> URL {
    let fileManager = FileManager.default
    let rootDir = fileManager.containerURL(
      forSecurityApplicationGroupIdentifier: "group.net.defined.mobileNebula")!

    if !fileManager.fileExists(atPath: rootDir.absoluteString) {
      try fileManager.createDirectory(at: rootDir, withIntermediateDirectories: true)
    }

    return rootDir
  }

  /// Gets the directory where all sites live, $rootDir/sites. Does ensure the directory exists
  static func getSitesDir() throws -> URL {
    let fileManager = FileManager.default
    let sitesDir = try getRootDir().appendingPathComponent("sites", isDirectory: true)
    if !fileManager.fileExists(atPath: sitesDir.absoluteString) {
      try fileManager.createDirectory(at: sitesDir, withIntermediateDirectories: true)
    }
    return sitesDir
  }

  /// Gets the directory where a single site would live, $rootDir/sites/$siteID
  static func getSiteDir(id: String, create: Bool = false) throws -> URL {
    let fileManager = FileManager.default
    let siteDir = try getSitesDir().appendingPathComponent(id, isDirectory: true)
    if create && !fileManager.fileExists(atPath: siteDir.absoluteString) {
      try fileManager.createDirectory(at: siteDir, withIntermediateDirectories: true)
    }
    return siteDir
  }

  /// Gets the file that represents the site configuration, $rootDir/sites/$siteID/config.json
  static func getSiteConfigFile(id: String, createDir: Bool) throws -> URL {
    return try getSiteDir(id: id, create: createDir).appendingPathComponent(
      "config", isDirectory: false
    ).appendingPathExtension("json")
  }

  /// Gets the file that represents the site log output, $rootDir/sites/$siteID/log
  static func getSiteLogFile(id: String, createDir: Bool) throws -> URL {
    return try getSiteDir(id: id, create: createDir).appendingPathComponent(
      "logs", isDirectory: false
    )
  }

  init?() async {
    _ = await loadSites()
  }

  func loadSites() async -> Result<SiteDictionary, any Error> {
    #if targetEnvironment(simulator)
      let sitesResult = await SiteList.loadAllFromFS()
      switch sitesResult {
      case .success(let sites):
        self.sites = sites
        return .success(sites)
      case .failure(let error):
        return .failure(error)
      }
    #else
      let sitesResult = await SiteList.loadAllFromNETPM()
      switch sitesResult {
      case .success(let sites):
        self.sites = sites
        return .success(sites)
      case .failure(let error):
        return .failure(error)
      }
    #endif
  }

  private static func loadAllFromFS() async -> Result<SiteDictionary, any Error> {
    let fileManager = FileManager.default
    var siteDirs: [URL]
    var sites = [String: Site]()

    do {
      siteDirs = try fileManager.contentsOfDirectory(
        at: getSitesDir(), includingPropertiesForKeys: nil
      )

    } catch {
      return Result.failure(error)
    }

    for path in siteDirs {
      do {
        let site = try Site(
          path: path.appendingPathComponent("config").appendingPathExtension("json"))
        sites[site.id] = site

      } catch {
        print(error)
        try? fileManager.removeItem(at: path)
        print("Deleted non conforming site \(path)")
      }
    }

    return Result.success(sites)
  }

  private static func loadAllFromNETPM() async -> Result<SiteDictionary, any Error> {
    var sites = [String: Site]()

    do {
      let newManagers = try await NETunnelProviderManager.loadAllFromPreferences()
      for manager in newManagers {
        do {
          let site = try Site(manager: manager)
          if site.needsToMigrateToFS {
            let error = await withCheckedContinuation({ continuation in
              site.incomingSite?.save(manager: manager) { error in
                continuation.resume(returning: error)
              }
            })

            if error != nil {
              print("Error while migrating site to fs: \(error!.localizedDescription)")
            }

            print("Migrated site to fs: \(site.name)")
            site.needsToMigrateToFS = false

          }
          sites[site.id] = site

        } catch {
          // TODO: notify the user about this
          print("Deleted non conforming site \(manager) \(error)")
          try await manager.removeFromPreferences()
          // TODO: delete from disk, we need to try and discover the site id though
        }
      }

      return Result.success(sites)

    } catch {
      return Result.failure(error)
    }
  }

  func getSites() -> SiteDictionary {
    return sites
  }
}
