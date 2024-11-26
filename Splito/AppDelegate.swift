//
//  AppDelegate.swift
//  Splito
//
//  Created by Amisha Italiya on 12/02/24.
//

import UIKit
import Data
import Foundation
import FirebaseCore
import GoogleSignIn
import FirebaseMessaging
import UserNotifications
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        addDDLoggers()
        FirebaseProvider.configureFirebase()
        registerForPushNotifications(application: application)
        return true
    }

    private func registerForPushNotifications(application: UIApplication) {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        let options: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { (granted, error) in
            if let error {
                LogE("AppDelegate: \(#function) Failed to request notification authorization: \(error).")
                return
            }
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        if let activityId = userInfo["activityId"] as? String {
            DispatchQueue.main.async { [weak self] in
                NotificationCenter.default.post(name: .showActivityLog, object: self, userInfo: ["activityId": activityId])
            }
        } else {
            LogE("AppDelegate: \(#function) Activity id not found in notification data.")
        }
        completionHandler()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        FirebaseProvider.auth.setAPNSToken(deviceToken, type: .sandbox)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(.noData)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        LogE("AppDelegate: \(#function) Failed to register for remote notifications: \(error).")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else {
            LogE("AppDelegate: \(#function) Device fcm token not found.")
            return
        }

        @Inject var preference: SplitoPreference
        guard let userId = preference.user?.id else { return }
        updateDeviceFcmToken(userId: userId, fcmToken: fcmToken)
    }

    func updateDeviceFcmToken(userId: String, fcmToken: String, retryCount: Int = 3) {
        Firestore.firestore().collection("users").document(userId).setData([
            "device_fcm_token": fcmToken
        ], merge: true) { error in
            if let error {
                LogE("AppDelegate: \(#function) Failed to update device fcm token: \(error).")
                if retryCount > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.updateDeviceFcmToken(userId: userId, fcmToken: fcmToken, retryCount: retryCount - 1)
                    }
                }
            } else {
                LogI("AppDelegate: \(#function) Device fcm token updated successfully.")
            }
        }
    }
}
