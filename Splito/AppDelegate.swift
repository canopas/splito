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
        registerForPushNotifications()
        return true
    }

    func registerForPushNotifications() {
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]

        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { (granted, _) in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        FirebaseProvider.auth.setAPNSToken(deviceToken, type: .sandbox)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        guard let fcmToken = fcmToken else { return }
        // Update Firestore with the refreshed token
        updateFCMTokenInFirestore(token: fcmToken)
    }

    func updateFCMTokenInFirestore(token: String) {
        @Inject var preference: SplitoPreference
        guard let userId = preference.user?.id else { return }

        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "deviceFcmToken": token
        ]) { error in
            if let error = error {
                print("Error updating FCM token: \(error)")
            } else {
                print("FCM token successfully updated in Firestore")
            }
        }
    }
}
