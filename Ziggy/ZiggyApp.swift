////
////  ZiggyApp.swift
////  Ziggy
////
////  Created by Manrai Singh on 09/05/26.
////
//
//import SwiftUI
//import UserNotifications
//@main
//struct ZiggyApp: App {
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//                .onAppear {
//                    requestNotificationPermission()
//                }
//        }
//    }
//    func requestNotificationPermission() {
//
//        UNUserNotificationCenter.current()
//            .requestAuthorization(
//                options: [.alert, .sound, .badge]
//            ) { granted, error in
//
//                print("Permission:", granted)
//            }
//    }
//}
import SwiftUI
import UserNotifications
import FirebaseCore
import FirebaseAuth

@main
struct ZiggyApp: App {

    init() {
        FirebaseApp.configure()

        // Silent anonymous sign-in so every device has a stable identity.
        // Used by Firestore security rules to limit access to the two
        // partners in a relationship.
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .onAppear {
                    requestNotificationPermission()
                }
        }
    }

    func requestNotificationPermission() {

        UNUserNotificationCenter.current()
            .requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { granted, error in

            }
    }
}
