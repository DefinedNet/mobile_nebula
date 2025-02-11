import Foundation
import os.log

actor DNUpdater {
    private let apiClient = APIClient()
    private let timer = RepeatingTimer(timeInterval: 15 * 60)  // 15 * 60 is 15 minutes
    private let log = Logger(subsystem: "net.defined.mobileNebula", category: "DNUpdater")

    private func updateAll(onUpdate: @escaping (Site) -> Void) {
        SiteList.loadAll(completion: { (sites, _) -> Void in
            if let unwrappedSites = sites?.values {
                // NEVPN seems to force us onto the main thread and we are about to make network calls that
                // could block for a while. Push ourselves onto another thread to avoid blocking the UI.
                Task.detached(priority: .userInitiated) {
                    for site in unwrappedSites {
                        if site.connected == true {
                            // The vpn service is in charge of updating the currently connected site
                            return
                        }

                        await self.updateSite(site: site, onUpdate: onUpdate)
                    }

                }

            }

        })
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

    private func updateSite(site: Site, onUpdate: @escaping (Site) -> Void) {
        do {
            if !site.managed {
                return
            }

            let credentials = try site.getDNCredentials()

            let newSite: IncomingSite?
            do {
                newSite = try apiClient.tryUpdate(
                    siteName: site.name,
                    hostID: credentials.hostID,
                    privateKey: credentials.privateKey,
                    counter: credentials.counter,
                    trustedKeys: credentials.trustedKeys
                )
            } catch (APIClientError.invalidCredentials) {
                if !credentials.invalid {
                    try site.invalidateDNCredentials()
                    log.notice("Invalidated credentials in site: \(site.name, privacy: .public)")
                }

                return
            }

            let siteManager = site.manager
            let shouldSaveToManager =
                siteManager != nil
                || ProcessInfo().isOperatingSystemAtLeast(
                    OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0))

            newSite?.save(manager: site.manager, saveToManager: shouldSaveToManager) { error in
                if error != nil {
                    self.log.error("failed to save update: \(error!.localizedDescription, privacy: .public)")
                }

                // reload nebula even if we couldn't save the vpn profile
                onUpdate(Site(incoming: newSite!))
            }

            if credentials.invalid {
                try site.validateDNCredentials()
                log.notice("Revalidated credentials in site \(site.name, privacy: .public)")
            }

        } catch {
            log.error(
                "Error while updating \(site.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
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
