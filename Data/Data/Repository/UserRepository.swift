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
        if var fetchedUser = try await fetchUserBy(userID: user.id) {
            LogD("UserRepository: \(#function) User already exists in Firestore.")
            if !fetchedUser.isActive || user.loginType != fetchedUser.loginType || user.emailId != fetchedUser.emailId {
                fetchedUser.isActive = true
                fetchedUser.loginType = user.loginType
                fetchedUser.emailId = (user.emailId == nil || user.emailId == "") ? fetchedUser.emailId : user.emailId
                return try await updateUser(user: fetchedUser)
            }
            return fetchedUser
        } else {
            LogD("UserRepository: \(#function) User does not exist. Adding new user.")
            try await store.addUser(user: user)
            LogD("UserRepository: \(#function) User stored successfully.")
            return user
        }
    }

    public func fetchUserBy(userID: String) async throws -> AppUser? {
        try await store.fetchUserBy(id: userID)
    }

    public func fetchUserBy(email: String) async throws -> AppUser? {
        try await store.fetchUserBy(email: email)
    }

    public func streamLatestUserBy(userID: String) -> AsyncStream<AppUser?> {
        store.streamLatestUserBy(id: userID)
    }

    private func uploadImage(imageData: Data, user: AppUser) async throws -> AppUser {
        let imageURL = try await storageManager.uploadAttachment(for: .user, id: user.id, attachmentData: imageData)
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

            _ = try await storageManager.deleteAttachment(attachmentUrl: currentUrl)
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

    public func deleteUser(user: AppUser) async throws {
        do {
            try await store.deactivateUserAfterDelete(userId: user.id)
            try await deleteUserFromAuth()
        } catch {
            // Rollback deactivation if auth deletion fails
            _ = try await store.updateUser(user: user)
            throw error
        }
    }

    private func deleteUserFromAuth() async throws {
        guard let user = FirebaseProvider.auth.currentUser else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No logged-in user found"])
        }
        try await user.delete()
    }

    public func updateDeviceFcmToken(retryCount: Int = 3) async {
        guard let userId = preference.user?.id, let fcmToken = preference.fcmToken else { return }

        do {
            try await store.updateUserDeviceFcmToken(userId: userId, fcmToken: fcmToken)
            LogI("UserRepository: \(#function) Device fcm token updated successfully.")
        } catch {
            LogE("UserRepository: \(#function) Failed to update device fcm token: \(error).")
            if retryCount > 0 {
                await updateDeviceFcmToken(retryCount: retryCount - 1)
            }
        }
    }
}
