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
import UIKit
import FirebaseCore
import FirebaseAuth

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken
            .map { String(format: "%02.2hhx", $0) }
            .joined()

        FirestoreManager.shared.saveDeviceToken(token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        WidgetDataManager.shared.saveRemoteWidgetEvent(userInfo)
        WidgetDataManager.shared.clearPartnerMessageIfExpired()
        completionHandler(.newData)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}

@main
struct ZiggyApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

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
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSNotification.Name("RelationshipChanged")
                    )
                ) { _ in
                    requestNotificationPermission()
                }
        }
    }

    func requestNotificationPermission() {

        UNUserNotificationCenter.current()
            .requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { granted, error in
                guard granted else { return }

                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    FirestoreManager.shared.refreshSavedDeviceToken()
                }
            }
    }
}
