import Foundation

class DNUpdater {
    private let apiClient = APIClient()
    private let timer = RepeatingTimer(timeInterval: 15 * 60) // 15 * 60 is 15 minutes
    
    func updateAll(onUpdate: @escaping (Site) -> ()) {
        _ = SiteList{ (sites, _) -> () in
            sites?.values.forEach { site in
                if (site.connected == true) {
                    // The vpn service is in charge of updating the currently connected site
                    return
                }
                
                self.updateSite(site: site, onUpdate: onUpdate)
            }
        }
    }
    
    func updateAllLoop(onUpdate: @escaping (Site) -> ()) {
        timer.eventHandler = {
            self.updateAll(onUpdate: onUpdate)
        }
        timer.resume()
    }
    
    func updateSingleLoop(site: Site, onUpdate: @escaping (Site) -> ()) {
        timer.eventHandler = {
            self.updateSite(site: site, onUpdate: onUpdate)
        }
        timer.resume()
    }
    
    func updateSite(site: Site, onUpdate: @escaping (Site) -> ()) {
        do {
            if (!site.managed) {
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
                if (!credentials.invalid) {
                    try site.invalidateDNCredentials()
                    print("Invalidated credentials in site \(site.name)")
                }
                
                return
            }
            
            newSite?.save(manager: nil) { error in
                if (error != nil) {
                    print("failed to save update: \(error!.localizedDescription)")
                } else {
                    onUpdate(Site(incoming: newSite!))
                }
            }
            
            if (credentials.invalid) {
                try site.validateDNCredentials()
                print("Revalidated credentials in site \(site.name)")
            }
            
        } catch {
            print("Error while updating \(site.name): \(error.localizedDescription)")
        }
    }
}

// From https://medium.com/over-engineering/a-background-repeating-timer-in-swift-412cecfd2ef9
class RepeatingTimer {

    let timeInterval: TimeInterval

    init(timeInterval: TimeInterval) {
        self.timeInterval = timeInterval
    }

    private lazy var timer: DispatchSourceTimer = {
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
