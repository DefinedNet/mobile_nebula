import Foundation
import os.log

class DNUpdater {
  private let apiClient = APIClient()
  private let timer = RepeatingTimer(timeInterval: 15 * 60)  // 15 * 60 is 15 minutes
  private let log = Logger(subsystem: "net.defined.mobileNebula", category: "DNUpdater")

  func updateAll(onUpdate: @escaping (Site) -> Void) {
    _ = SiteList { (sites, _) -> Void in
      // NEVPN seems to force us onto the main thread and we are about to make network calls that
      // could block for a while. Push ourselves onto another thread to avoid blocking the UI.
      Task.detached(priority: .userInitiated) {
        sites?.values.forEach { site in
          if site.connected == true {
            // The vpn service is in charge of updating the currently connected site
            return
          }

          self.updateSite(site: site, onUpdate: onUpdate)
        }
      }
    }
  }

  func updateAllLoop(onUpdate: @escaping (Site) -> Void) {
    timer.eventHandler = {
      self.updateAll(onUpdate: onUpdate)
    }
    timer.resume()
  }

  func updateSingleLoop(site: Site, onUpdate: @escaping (Site) -> Void) {
    timer.eventHandler = {
      self.updateSite(site: site, onUpdate: onUpdate)
    }
    timer.resume()
  }

  func updateSite(site: Site, onUpdate: @escaping (Site) -> Void) {
    do {
      if !site.managed {
        return
      }

      let credentials = try site.getDNCredentials()

      guard let nebulaCert = site.cert?.rawCert else {
        throw SiteError.noCertificate
      }

      let nebulaKey = try site.getKey()

      let newSiteJson: String?
      do {
        newSiteJson = try apiClient.tryUpdate(
          siteName: site.name,
          hostID: credentials.hostID,
          privateKey: credentials.privateKey,
          counter: credentials.counter,
          trustedKeys: credentials.trustedKeys,
          nebulaCert: nebulaCert,
          nebulaKey: nebulaKey
        )
      } catch APIClientError.invalidCredentials {
        if !credentials.invalid {
          try site.invalidateDNCredentials()
          log.notice("Invalidated credentials in site: \(site.name, privacy: .public)")
        }

        return
      }

      if var newSiteJson = newSiteJson {
        // Preserve client-only fields that the server doesn't know about
        newSiteJson = preserveClientFields(existingSite: site, newSiteJson: newSiteJson)

        let siteManager = site.manager
        let shouldSaveToManager =
          siteManager != nil
          || ProcessInfo().isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0))

        saveSite(jsonString: newSiteJson, manager: site.manager, saveToManager: shouldSaveToManager)
        { error in
          if error != nil {
            self.log.error(
              "failed to save update: \(error!.localizedDescription, privacy: .public)")
          }

          // Reload site from disk and notify
          do {
            let configPath = try SiteList.getSiteConfigFile(id: site.id, createDir: false)
            let newSite = try Site(path: configPath)
            onUpdate(newSite)
          } catch {
            self.log.error(
              "failed to reload site: \(error.localizedDescription, privacy: .public)")
          }
        }
      }

      if credentials.invalid {
        try site.validateDNCredentials()
        log.notice("Revalidated credentials in site \(site.name, privacy: .public)")
      }

    } catch {
      log.error(
        "Error while updating \(site.name, privacy: .public): \(error.localizedDescription, privacy: .public)"
      )
    }
  }
}

/// Injects client-only fields from the existing site into the new site JSON returned by a DN
/// update. The server doesn't know about these fields, so without this they would be lost.
private func preserveClientFields(existingSite site: Site, newSiteJson: String) -> String {
  guard let data = newSiteJson.data(using: .utf8),
    let obj = try? JSONSerialization.jsonObject(with: data),
    var map = obj as? [String: Any]
  else {
    return newSiteJson
  }

  if map["sortKey"] == nil {
    map["sortKey"] = site.sortKey
  }
  if map["alwaysOn"] == nil {
    map["alwaysOn"] = site.alwaysOn
  }

  guard let updatedData = try? JSONSerialization.data(withJSONObject: map),
    let updatedJson = String(data: updatedData, encoding: .utf8)
  else {
    return newSiteJson
  }

  return updatedJson
}

// From https://medium.com/over-engineering/a-background-repeating-timer-in-swift-412cecfd2ef9
class RepeatingTimer {

  let timeInterval: TimeInterval

  init(timeInterval: TimeInterval) {
    self.timeInterval = timeInterval
  }

  private lazy var timer: any DispatchSourceTimer = {
    let t = DispatchSource.makeTimerSource()
    t.schedule(deadline: .now(), repeating: self.timeInterval)
    t.setEventHandler(handler: { [weak self] in
      self?.eventHandler?()
    })
    return t
  }()

  var eventHandler: (() -> Void)?

  private enum State {
    case suspended
    case resumed
  }

  private var state: State = .suspended

  deinit {
    timer.setEventHandler {}
    timer.cancel()
    /*
         If the timer is suspended, calling cancel without resuming
         triggers a crash. This is documented here https://forums.developer.apple.com/thread/15902
         */
    resume()
    eventHandler = nil
  }

  func resume() {
    if state == .resumed {
      return
    }
    state = .resumed
    timer.resume()
  }

  func suspend() {
    if state == .suspended {
      return
    }
    state = .suspended
    timer.suspend()
  }
}
