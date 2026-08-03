import Foundation
import MobileNebula

enum ConfigMigrator {
  /// Brings a site config up to date and writes it back to disk if anything changed.
  ///
  /// The migrations themselves all live in Go. This knows nothing about individual versions, it
  /// only supplies the private key that Go can't reach and handles the file, so adding a
  /// migration should not need a change here.
  static func migrate(configData: Data, path: URL) throws -> Data {
    let oldJson = String(data: configData, encoding: .utf8) ?? "{}"

    // Only the legacy format needs the key, so don't pay for a keychain read on every site load
    var key = ""
    if MobileNebulaMigrationNeedsKey(oldJson) {
      var siteId = ""
      if let obj = try? JSONSerialization.jsonObject(with: configData),
        let configMap = obj as? [String: Any]
      {
        siteId = configMap["id"] as? String ?? ""
      }

      if let keyData = KeyChain.load(key: "\(siteId).key") {
        key = String(decoding: keyData, as: UTF8.self)
      }
    }

    var err: NSError?
    let newJson = MobileNebulaMigrateConfig(oldJson, key, &err)
    if let err = err {
      throw err
    }

    // Go hands back the input verbatim when there is nothing to do
    if newJson == oldJson {
      return configData
    }

    guard let newData = newJson.data(using: .utf8) else {
      return configData
    }

    try newData.write(to: path)
    return newData
  }
}
