import MobileNebula

enum APIClientError: Error {
  case invalidCredentials
}

class APIClient {
  let apiClient: MobileNebulaAPIClient

  init() {
    let packageInfo = PackageInfo()
    apiClient = MobileNebulaNewAPIClient(
      "MobileNebula/\(packageInfo.getVersion()) (iOS \(packageInfo.getSystemVersion()))")!
  }

  func enroll(code: String) throws -> String {
    let res = try apiClient.enroll(code)
    return res.site
  }

  func tryUpdate(
    siteName: String, hostID: String, privateKey: String, counter: Int, trustedKeys: String
  ) throws -> String? {
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
      return res.site
    }

    return nil
  }
}
