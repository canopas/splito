//
//  UserStore.swift
//  Data
//
//  Created by Amisha Italiya on 16/03/24.
//

import FirebaseFirestore

class UserStore: ObservableObject {

    private let COLLECTION_NAME: String = "users"

    @Inject private var database: Firestore

    private var usersCollection: CollectionReference {
        database.collection(COLLECTION_NAME)
    }

    func addUser(user: AppUser) async throws {
        try usersCollection.document(user.id).setData(from: user)
    }

    func updateUser(user: AppUser) async throws -> AppUser? {
        try usersCollection.document(user.id).setData(from: user, merge: false)
        return user
    }

    func fetchUserBy(id: String) async throws -> AppUser? {
        let document = try await usersCollection.document(id).getDocument(source: .server)

        if document.exists {
            let fetchedUser = try document.data(as: AppUser.self)
            LogD("UserStore: \(#function) User fetched successfully.")
            return fetchedUser
        } else {
            LogE("UserStore: \(#function) snapshot is nil for requested user.")
            return nil
        }
    }

    func fetchUserBy(email: String) async throws -> AppUser? {
        let snapshot = try await usersCollection.whereField("email_id", isEqualTo: email).getDocuments()

        if let document = snapshot.documents.first {
            let fetchedUser = try document.data(as: AppUser.self)
            LogD("UserStore: \(#function) User fetched successfully by email.")
            return fetchedUser
        } else {
            LogE("UserStore: \(#function) No user found for the provided email.")
            return nil
        }
    }

    func fetchLatestUserBy(id: String) -> AsyncStream<AppUser?> {
        AsyncStream { continuation in
            let listener = usersCollection.document(id).addSnapshotListener { snapshot, error in
                if let error {
                    LogE("UserStore: \(#function) Error fetching document: \(error).")
                    continuation.finish()
                    return
                }

                guard let snapshot else {
                    LogE("UserStore: \(#function) Snapshot is nil for requested user.")
                    continuation.yield(nil)
                    return
                }

                do {
                    let user = try snapshot.data(as: AppUser.self)
                    continuation.yield(user)
                } catch {
                    LogE("UserStore: \(#function) Error decoding user data: \(error).")
                    continuation.finish()
                }
            }

            // Clean up: Remove listener when the stream is cancelled
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func updateUserDeviceFcmToken(userId: String, fcmToken: String) async throws {
        try await usersCollection.document(userId).setData(["device_fcm_token": fcmToken], merge: true)
    }

    func deactivateUserAfterDelete(userId: String) async throws {
        try await usersCollection.document(userId)
            .updateData([
                "is_active": false,
                "email_id": "",
                "login_type": "",
                "phone_number": "",
                "device_fcm_token": ""
            ])
    }
}
