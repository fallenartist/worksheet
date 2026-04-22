import Foundation
import Security

final class KeychainStore {
    static let shared = KeychainStore()

    private let service = "Worksheet"
    private let apiKeyAccount = "DailyAPIKey"

    private init() {}

    func loadAPIKey() -> String {
        var query = baseQuery(account: apiKeyAccount)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func saveAPIKey(_ apiKey: String) {
        let data = Data(apiKey.utf8)
        let query = baseQuery(account: apiKeyAccount)
        let attributes = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
