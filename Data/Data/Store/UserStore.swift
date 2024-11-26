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

    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    private var usersCollection: CollectionReference {
        database.collection(COLLECTION_NAME)
    }

    func addUser(user: AppUser) async throws {
        try usersCollection.document(user.id).setData(from: user)
    }

    func updateUser(user: AppUser) async throws -> AppUser? {
        try usersCollection.document(user.id).setData(from: user, merge: true)
        return user
    }

    func fetchUserBy(id: String) async throws -> AppUser? {
        let snapshot = try await usersCollection.document(id).getDocument(source: .server)
        return try snapshot.data(as: AppUser.self)
    }

    func fetchLatestUserBy(id: String, completion: @escaping (AppUser?) -> Void) {
        listener?.remove()
        listener = usersCollection.document(id).addSnapshotListener { snapshot, error in
            if let error {
                LogE("UserStore: \(#function) Error fetching document: \(error).")
                completion(nil)
                return
            }

            guard let snapshot else {
                LogE("UserStore: \(#function) snapshot is nil for requested user.")
                completion(nil)
                return
            }

            do {
                let user = try snapshot.data(as: AppUser.self)
                LogD("UserStore: \(#function) Latest user fetched successfully.")
                completion(user)
            } catch {
                LogE("UserStore: \(#function) Error decoding user data: \(error).")
                completion(nil)
            }
        }
    }

    func deactivateUserAfterDelete(userId: String) async throws {
        try await usersCollection.document(userId).updateData(["is_active": false])
    }
}
