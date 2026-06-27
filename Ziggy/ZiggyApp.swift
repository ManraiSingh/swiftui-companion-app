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

@main
struct ZiggyApp: App {

    init() {
        FirebaseApp.configure()
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
