import Foundation
import Security

final class KeychainSessionStore {
    private let service = "com.orthoorganizer.apple.session"
    private let account = "cloud-session"

    func save(_ session: OrganizerRemoteSession) {
        let payload: [String: Any] = [
            "username": session.username,
            "uid": session.uid,
            "vaultID": session.vaultID,
            "refreshToken": session.refreshToken,
            "archiveKey": session.archiveKey.base64EncodedString()
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func load() -> OrganizerRemoteSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any],
              let username = payload["username"] as? String,
              let uid = payload["uid"] as? String,
              let vaultID = payload["vaultID"] as? String,
              let refreshToken = payload["refreshToken"] as? String,
              let encodedKey = payload["archiveKey"] as? String,
              let key = Data(base64Encoded: encodedKey) else {
            return nil
        }
        return OrganizerRemoteSession(username: username,
                                      uid: uid,
                                      vaultID: vaultID,
                                      refreshToken: refreshToken,
                                      archiveKey: key)
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
