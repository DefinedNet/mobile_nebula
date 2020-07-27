import Foundation

let groupName = "group.net.defined.mobileNebula"

class KeyChain {
    class func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword as String,
            kSecAttrAccount as String : key,
            kSecValueData as String   : data,
            kSecAttrAccessGroup as String: groupName,
        ]

        SecItemDelete(query as CFDictionary)
        let val = SecItemAdd(query as CFDictionary, nil)
        return  val == 0
    }

    class func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrAccount as String : key,
            kSecReturnData as String  : kCFBooleanTrue!,
            kSecMatchLimit as String  : kSecMatchLimitOne,
            kSecAttrAccessGroup as String: groupName,
        ]

        var dataTypeRef: AnyObject? = nil

        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == noErr {
            return dataTypeRef as! Data?
        } else {
            return nil
        }
    }
    
    class func delete(key: String) -> Bool {
       let query: [String: Any] = [
           kSecClass as String       : kSecClassGenericPassword,
           kSecAttrAccount as String : key,
           kSecReturnData as String  : kCFBooleanTrue!,
           kSecMatchLimit as String  : kSecMatchLimitOne,
           kSecAttrAccessGroup as String: groupName,
       ]

        return SecItemDelete(query as CFDictionary) == 0
    }
}

extension Data {

    init<T>(from value: T) {
        var value = value
        var data = Data()
        withUnsafePointer(to: &value, { (ptr: UnsafePointer<T>) -> Void in
            data = Data(buffer: UnsafeBufferPointer(start: ptr, count: 1))
        })
        self.init(data)
    }

    func to<T>(type: T.Type) -> T {
        return self.withUnsafeBytes { $0.load(as: T.self) }
    }
}

