//
//  SplitoApp.swift
//  Splito
//
//  Created by Amisha Italiya on 12/02/24.
//

import SwiftUI
import Data
import UserNotifications

@main
struct SplitoApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        Injector.shared.initInjector()
        setupNotificationHandling() // Setup notification handling here
    }

    var body: some Scene {
        WindowGroup {
            MainRouteView()
        }
    }

    private func setupNotificationHandling() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        NotificationDelegate.shared.notificationTapped = { userInfo in
            print("Notification tapped: \(userInfo)")

            if let activityId = userInfo["activityId"] as? String {
                DispatchQueue.main.async {
                    // Access the HomeRouteViewModel correctly
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController as? UIHostingController<MainRouteView> {
                        // Directly access the homeRouteViewModel
                        rootViewController.rootView.homeRouteViewModel.switchToActivityLog(activityId: activityId)
                    }
                }
            }
        }
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    var notificationTapped: (([AnyHashable: Any]) -> Void)?

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        notificationTapped?(userInfo)
        completionHandler()
    }
}
