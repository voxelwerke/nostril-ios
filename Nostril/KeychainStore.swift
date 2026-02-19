//
//  KeychainStore.swift
//  Nostril
//

import Security
import LocalAuthentication
import SwiftUI

enum KeychainStore {
    private static let account = "nostr_private_key_nsec"
    private static let backupsAccount = "nostr_private_key_backups"
    private static let service = Bundle.main.bundleIdentifier ?? "Nostril"

    // MARK: - Primary Key (NO Face ID)

    static func storeNsec(_ nsec: String) {
        let data = Data(nsec.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            var addQuery = query
            for (k, v) in attributes { addQuery[k] = v }
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func loadNsec() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data
        else { return nil }

        return String(data: data, encoding: .utf8)
    }

    static func deleteNsec() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Face ID Protected Backups

    private static func makeAccessControl() -> SecAccessControl? {
        SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil
        )
    }

    static func loadBackups() -> [String] {
        let context = LAContext()
        context.localizedReason = "Authenticate to access key backups"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: backupsAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return [] }

        return string
            .split(separator: ",")
            .map { String($0) }
            .filter { !$0.isEmpty }
    }

    static func storeBackups(_ backups: [String]) {
        guard let accessControl = makeAccessControl() else { return }

        let unique = Array(Set(backups))
        let joined = unique.joined(separator: ",")
        let data = Data(joined.utf8)

        let context = LAContext()
        context.localizedReason = "Authenticate to update key backups"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: backupsAccount
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl,
            kSecUseAuthenticationContext as String: context
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)

        if status == errSecSuccess {
            SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            var addQuery = query
            for (k, v) in attributes { addQuery[k] = v }
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func logout() {
        deleteNsec()
    }
    
    
    static func backupCurrentAndLogout() {
        guard let current = loadNsec(), !current.isEmpty else { return }

        var backups = loadBackups()
        backups.append(current)

        storeBackups(backups)
        deleteNsec()
    }
}
