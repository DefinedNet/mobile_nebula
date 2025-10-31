@preconcurrency import MobileNebula

enum APIClientError: Error {
  case invalidCredentials
}

struct APIClient: Sendable {
  let apiClient: MobileNebulaAPIClient
  let json = JSONDecoder()

  init() {
    let packageInfo = PackageInfo()
    apiClient = MobileNebulaNewAPIClient(
      "MobileNebula/\(packageInfo.getVersion()) (iOS \(packageInfo.getSystemVersion()))")!
  }

  func enroll(code: String) throws -> IncomingSite {
    let res = try apiClient.enroll(code)
    return try decodeIncomingSite(jsonSite: res.site)
  }

  func tryUpdate(
    siteName: String, hostID: String, privateKey: String, counter: Int, trustedKeys: String
  ) throws -> IncomingSite? {
    let res: MobileNebulaTryUpdateResult
    do {
      res = try apiClient.tryUpdate(
        siteName,
        hostID: hostID,
        privateKey: privateKey,
        counter: counter,
        trustedKeys: trustedKeys)
    } catch {
      // type information from Go is not available, use string matching instead
      if error.localizedDescription == "invalid credentials" {
        throw APIClientError.invalidCredentials
      }

      throw error
    }

    if res.fetchedUpdate {
      return try decodeIncomingSite(jsonSite: res.site)
    }

    return nil
  }

  private func decodeIncomingSite(jsonSite: String) throws -> IncomingSite {
    do {
      return try json.decode(IncomingSite.self, from: jsonSite.data(using: .utf8)!)
    } catch {
      print("decodeIncomingSite: \(error)")
      throw error
    }
  }
}
