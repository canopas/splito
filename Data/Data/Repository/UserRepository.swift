//
//  UserRepository.swift
//  Data
//
//  Created by Amisha Italiya on 26/02/24.
//

import SwiftUI

public class UserRepository: ObservableObject {

    @Inject private var store: UserStore
    @Inject private var preference: SplitoPreference
    @Inject private var storageManager: StorageManager

    public func storeUser(user: AppUser) async throws -> AppUser {
        if var fetchedUser = try await store.fetchUserBy(id: user.id) {
            LogD("UserRepository: \(#function) User already exists in Firestore.")
            if !fetchedUser.isActive {
                fetchedUser.isActive = true
                return try await updateUser(user: fetchedUser)
            }
            return fetchedUser
        } else {
            LogD("UserRepository: \(#function) User does not exist. Adding new user.")
            try await store.addUser(user: user)
            return user
        }
    }

    public func fetchUserBy(userID: String) async throws -> AppUser? {
        return try await store.fetchUserBy(id: userID)
    }

    public func fetchLatestUserBy(userID: String, completion: @escaping (AppUser?) -> Void) {
        store.fetchLatestUserBy(id: userID) { user in
            completion(user)
        }
    }

    private func uploadImage(imageData: Data, user: AppUser) async throws -> AppUser {
        let imageURL = try await storageManager.uploadImage(for: .user, id: user.id, imageData: imageData)
        var newUser = user
        newUser.imageUrl = imageURL
        return try await updateUser(user: newUser)
    }

    public func updateUser(user: AppUser) async throws -> AppUser {
        let updatedUser = try await store.updateUser(user: user)
        return updatedUser ?? user
    }

    public func updateUserWithImage(imageData: Data?, newImageUrl: String?, user: AppUser) async throws -> AppUser {
        var newUser = user

        if let currentUrl = user.imageUrl, newImageUrl == nil {
            newUser.imageUrl = newImageUrl

            _ = try await storageManager.deleteImage(imageUrl: currentUrl)
            return try await performImageAction(imageData: imageData, user: newUser)
        } else {
            return try await performImageAction(imageData: imageData, user: newUser)
        }
    }

    private func performImageAction(imageData: Data?, user: AppUser) async throws -> AppUser {
        if let imageData {
            return try await uploadImage(imageData: imageData, user: user)
        } else {
            return try await updateUser(user: user)
        }
    }

    public func deleteUser(id: String) async throws {
        try await store.deactivateUserAfterDelete(userId: id)
    }

    private func deleteUserFromAuth() async throws {
        Task {
            FirebaseProvider.auth.currentUser?.delete { error in
                if let error {
                    LogE("UserRepository: \(#function) Deleting user from Auth failed with error: \(error).")
                } else {
                    LogD("UserRepository: \(#function) User deactivated.")
                }
            }
        }
    }
}
