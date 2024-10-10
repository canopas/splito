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

    private func registerForPushNotifications(application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]

        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { (granted, _) in
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
        guard let fcmToken else { return }
        // Update the FCM token in Firestore for the current user
        updateFCMTokenInFirestore(token: fcmToken)
    }

    func updateFCMTokenInFirestore(token: String) {
        @Inject var preference: SplitoPreference
        guard let userId = preference.user?.id else { return }

        Firestore.firestore().collection("users").document(userId).setData([
            "deviceFcmToken": token
        ], merge: true) { error in
            if let error {
                LogE("Error updating FCM token: \(error)")
            } else {
                LogI("FCM token successfully updated in Firestore")
            }
        }
    }
}
