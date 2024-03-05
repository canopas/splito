//
//  AuthHandler.swift
//  Data
//
//  Created by Amisha Italiya on 26/02/24.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthState: ObservableObject {

    let auth = FirebaseProvider.auth

    @Published var currentUser: User?

    func signIn(with credential: AuthCredential, completion: ((AuthHandlerResult?, Error?) -> Void)?) {
        auth.signIn(with: credential)
    }

    func signOut() {
        try? auth.signOut()
    }

    // Function to fetch and store user details in Firestore
    func fetchAndStoreUserDetails(uid: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)

        userRef.getDocument { document, _ in
            if let document, document.exists {
                print("User details already exist.")
            } else {
                // User details not found, store in Firestore
                self.storeDefaultUserDetails(uid: uid)
            }
        }
    }

    // Function to store default user details in Firestore
    func storeDefaultUserDetails(uid: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)

        // You can customize the default user details based on your requirements
        let defaultUserDetails: [String: Any] = [
            "uid": uid,
            "displayName": "New User",
            "email": ""
            // Add more user details as needed
        ]

        userRef.setData(defaultUserDetails) { error in
            if let error {
                print("Error storing user details: \(error.localizedDescription)")
            } else {
                print("User details stored successfully.")
            }
        }
    }
}

public struct AuthHandlerResult {
    let uid: String
}
