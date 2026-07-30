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
        WidgetDataManager.shared.clearPartnerMessageIfExpired()
        WidgetDataManager.shared.clearDoodleIfExpired()

        // A doodle's image is far too big for a push payload, so the push is
        // just a signal — fetch the drawing, cache it for the widget, finish.
        if (userInfo["type"] as? String) == "doodle" {
            let sender = userInfo["sender"] as? String ?? "Your partner"
            FirestoreManager.shared.fetchLatestDoodle { data in
                if let base64 = data?["imageBase64"] as? String {
                    let pinned = data?["pinned"] as? Bool ?? false
                    WidgetDataManager.shared.cachePartnerDoodle(
                        base64: base64,
                        sender: sender,
                        pinned: pinned
                    )
                }
                completionHandler(.newData)
            }
            return
        }

        WidgetDataManager.shared.saveRemoteWidgetEvent(userInfo)
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
