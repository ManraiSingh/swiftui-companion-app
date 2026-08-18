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
//  Marked to synchronise, so it rides iCloud Keychain to a replacement phone
//  as well as surviving a reinstall on the same one.
//
//  Only ever read back for someone signed in with Apple. A user who chose to
//  stay anonymous keeps exactly the behaviour they have now: their data lives
//  on the phone and goes with it.
//

import Foundation
import Security

enum ZiggyKeychain {

    private static let service = "com.Manrai.Ziggy.account"

    static func set(_ value: String, for key: String) {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanTrue!
        ]

        SecItemDelete(query as CFDictionary)

        guard !value.isEmpty, let data = value.data(using: .utf8) else { return }

        var insert = query
        insert[kSecValueData as String] = data

        // Readable only once the phone has been unlocked at least once since
        // boot — the app needs this at launch, not in the background.
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        SecItemAdd(insert as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanTrue!,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }

        return value
    }

    static func remove(_ key: String) {
        set("", for: key)
    }

    // The two things worth keeping.
    static let relationshipKey = "relationship_code"
    static let usernameKey = "username"
}
