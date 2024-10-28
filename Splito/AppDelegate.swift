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
        Messaging.messaging().delegate = self
        registerForPushNotifications(application: application)
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        if let activityId = userInfo["activityId"] as? String {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .showActivityLog, object: nil, userInfo: ["activityId": activityId])
            }
        } else {
            LogE("Activity id not found in notification data.")
        }
        completionHandler()
    }

    private func registerForPushNotifications(application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]

        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { (granted, error) in
            if let error {
                LogE("Failed to request notification authorization: \(error)")
                return
            }
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        FirebaseProvider.auth.setAPNSToken(deviceToken, type: .sandbox)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        LogE("Fail to register for remote notifications with error: \(error)")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else {
            LogE("Received invalid FCM token")
            return
        }

        @Inject var preference: SplitoPreference
        guard let userId = preference.user?.id else { return }

        Firestore.firestore().collection("users").document(userId).setData([
            "device_fcm_token": fcmToken
        ], merge: true) { error in
            if let error {
                LogE("Error updating FCM token: \(error)")
            } else {
                LogI("FCM token successfully updated in Firestore")
            }
        }
    }
}
