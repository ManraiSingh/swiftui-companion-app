//
//  PersistenceManager.swift
//  Ziggy
//
//  Created by Manrai Singh on 14/06/26.
//

import Foundation

class PersistenceManager {

    static let shared = PersistenceManager()

    private let petKey = "saved_pet"

    func savePet(_ pet: Pet) {

        if let encoded = try? JSONEncoder().encode(pet) {
            UserDefaults.standard.set(encoded, forKey: petKey)
        }
    }

    func loadPet() -> Pet {

        guard let data = UserDefaults.standard.data(forKey: petKey),
              let pet = try? JSONDecoder().decode(Pet.self, from: data)
        else {
            return Pet()
        }

        return pet
    }
    func resetPet() {

        let freshPet = Pet()

        savePet(freshPet)
    }
}
