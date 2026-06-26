//
//  WidgetDataManager.swift
//  Ziggy
//

import Foundation
import WidgetKit

class WidgetDataManager {

    static let shared = WidgetDataManager()

    private let key = "ziggy_widget_pet"

    private let sharedDefaults = UserDefaults(
        suiteName: "group.com.manrai.ziggy"
    )

    func savePet(_ pet: Pet) {

        if let data = try? JSONEncoder().encode(pet) {

            sharedDefaults?.set(
                data,
                forKey: key
            )

            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func loadPet() -> Pet? {

        guard
            let data = sharedDefaults?.data(
                forKey: key
            ),
            let pet = try? JSONDecoder().decode(
                Pet.self,
                from: data
            )
        else {
            return nil
        }

        return pet
    }
}
