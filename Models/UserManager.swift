//
//  UserManager.swift
//  Ziggy
//
//  Created by Manrai Singh on 14/06/26.
//

import Foundation

class UserManager {

    static let shared = UserManager()

    private let key = "ziggy_username"

    var username: String {

        get {

            UserDefaults.standard.string(
                forKey: key
            ) ?? "Anonymous"
        }

        set {

            UserDefaults.standard.set(
                newValue,
                forKey: key
            )
        }
    }
}
