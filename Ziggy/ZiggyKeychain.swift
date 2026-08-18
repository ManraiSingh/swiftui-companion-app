//
//  ZiggyKeychain.swift
//  Ziggy
//
//  The small facts a reinstall should not lose: which relationship this person
//  is in, and what to call them.
//
//  UserDefaults is wiped when an app is deleted. The keychain is not — which is
//  how Firebase's own sign-in survives a reinstall, and why the app comes back
//  up already signed in but with no idea who it is paired with.
//
//  Only ever read back for someone signed in with Apple. A user who chose to
//  stay anonymous keeps exactly the behaviour they have now: their data lives
//  on the phone and goes with it.
//

import Foundation
import Security

enum ZiggyKeychain {

    private static let service = "com.Manrai.Ziggy.account"

    static let relationshipKey = "relationship_code"
    static let usernameKey = "username"

    private static func base(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }

    /// Stores a value, preferring the iCloud-synchronised keychain so it also
    /// reaches a replacement phone.
    ///
    /// Falls back to a device-local item when that write is refused, which it
    /// is on a phone with iCloud Keychain turned off. Without the fallback the
    /// value silently never got stored at all — and a reinstall had nothing to
    /// recover from, which looked exactly like the recovery being broken.
    static func set(_ value: String, for key: String) {

        remove(key)

        guard !value.isEmpty, let data = value.data(using: .utf8) else { return }

        var synced = base(key)
        synced[kSecAttrSynchronizable as String] = kCFBooleanTrue!
        synced[kSecValueData as String] = data
        synced[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(synced as CFDictionary, nil)
        guard status != errSecSuccess else { return }

        var local = base(key)
        local[kSecValueData as String] = data
        local[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let fallback = SecItemAdd(local as CFDictionary, nil)

        #if DEBUG
        if fallback != errSecSuccess {
            print("Keychain: could not store \(key) (\(status) then \(fallback))")
        }
        #endif
    }

    /// Reads a value, matching either the synchronised copy or the local one.
    static func get(_ key: String) -> String? {

        var query = base(key)
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        query[kSecReturnData as String] = kCFBooleanTrue!
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else {
            #if DEBUG
            if status != errSecItemNotFound {
                print("Keychain: could not read \(key) (\(status))")
            }
            #endif
            return nil
        }

        return value
    }

    static func remove(_ key: String) {
        var query = base(key)
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        SecItemDelete(query as CFDictionary)
    }
}
