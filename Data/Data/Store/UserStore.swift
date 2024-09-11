//
//  UserStore.swift
//  Data
//
//  Created by Amisha Italiya on 16/03/24.
//

import Combine
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
        try usersCollection.document(user.id).setData(from: user, merge: true)
        return user
    }

    func fetchUserBy(id: String) async throws -> AppUser? {
        let snapshot = try await usersCollection.document(id).getDocument()
        return try snapshot.data(as: AppUser.self)
    }

    func fetchLatestUserBy(id: String) async throws -> AppUser? {
        let snapshot = try await usersCollection.document(id).getDocument()
        return try snapshot.data(as: AppUser.self)
    }

    func deactivateUserAfterDelete(userId: String) async throws {
        try await usersCollection.document(userId).updateData(["is_active": false])
    }
}
