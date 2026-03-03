import Foundation
import MobileNebula

enum ConfigMigrator {
  /// Migrates config data to the latest version if needed.
  /// Writes the migrated config back to disk and returns the updated data.
  static func migrate(configData: Data, path: URL) throws -> Data {
    guard let configMap = try? JSONSerialization.jsonObject(with: configData) as? [String: Any]
    else {
      return configData
    }

    var version = configMap["configVersion"] as? Int ?? 0
    var result = configData

    if version < 1 {
      result = try migrateToV1(configData: result, configMap: configMap, path: path)
      version = 1
    }

    // Future migrations go here

    return result
  }

  /// Migrates from v0 (old decomposed format) to v1 (rawConfig format).
  private static func migrateToV1(
    configData: Data, configMap: [String: Any], path: URL
  ) throws -> Data {
    let siteId = configMap["id"] as? String ?? ""
    let key: String
    if let keyData = KeyChain.load(key: "\(siteId).key") {
      key = String(decoding: keyData, as: UTF8.self)
    } else {
      key = ""
    }

    let oldJson = String(data: configData, encoding: .utf8) ?? "{}"
    var err: NSError?
    let newJson = MobileNebulaMigrateConfig(oldJson, key, &err)
    if let err = err {
      throw err
    }

    guard let newData = newJson.data(using: .utf8) else {
      return configData
    }

    try newData.write(to: path)
    return newData
  }
}
