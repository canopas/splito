//
//  GroupRepository.swift
//  Data
//
//  Created by Amisha Italiya on 07/03/24.
//

import Combine
import SwiftUI
import FirebaseFirestore

public class GroupRepository: ObservableObject {

    @Inject private var store: GroupStore

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var storageManager: StorageManager
    @Inject private var codeRepository: ShareCodeRepository

    public func createGroup(group: Groups, imageData: Data?) async throws -> Groups {
        let groupId = try await store.createGroup(group: group)

        var newGroup = group
        newGroup.id = groupId

        // If image data is provided, upload the image and update the group's imageUrl
        if let imageData = imageData {
            let imageUrl = try await uploadImage(imageData: imageData, group: newGroup)
            newGroup.imageUrl = imageUrl
        }

        return newGroup
    }

    private func uploadImage(imageData: Data, group: Groups) async throws -> String {
        guard let groupId = group.id else { return "" }

        // Upload the image and get the image URL
        return try await storageManager.uploadImage(for: .group, id: groupId, imageData: imageData) ?? ""
    }

    public func updateGroupWithImage(imageData: Data?, newImageUrl: String?, group: Groups) async throws -> Groups {
        var newGroup = group

        // If image data is provided, upload the new image and update the imageUrl
        if let imageData = imageData {
            // Upload the image and get the new image URL
            let uploadedImageUrl = try await uploadImage(imageData: imageData, group: newGroup)
            newGroup.imageUrl = uploadedImageUrl
        } else if let currentUrl = group.imageUrl, newImageUrl == nil {
            // If there's a current image URL and we want to remove it, delete the image and set imageUrl to nil
            try await storageManager.deleteImage(imageUrl: currentUrl)
            newGroup.imageUrl = nil
        } else if let newImageUrl = newImageUrl {
            // If a new image URL is explicitly passed, update it
            newGroup.imageUrl = newImageUrl
        }

        try await updateGroup(group: newGroup)
        return newGroup
    }

    public func addMemberToGroup(groupId: String, memberId: String) async throws {
        try await store.addMemberToGroup(groupId: groupId, memberId: memberId)
    }

    public func updateGroup(group: Groups) async throws {
        try await store.updateGroup(group: group)
    }

    public func fetchGroupBy(id: String) async throws -> Groups? {
        return try await store.fetchGroupBy(id: id)
    }

    public func fetchGroupsBy(userId: String, limit: Int = 10, lastDocument: DocumentSnapshot? = nil) async throws -> (data: [Groups], lastDocument: DocumentSnapshot?) {
        return try await store.fetchGroupsBy(userId: userId, limit: limit, lastDocument: lastDocument)
    }

    public func fetchMemberBy(userId: String) async throws -> AppUser? {
        return try await userRepository.fetchUserBy(userID: userId)
    }

    public func fetchMembersBy(groupId: String) async throws -> [AppUser] {
        guard let group = try await fetchGroupBy(id: groupId) else { return [] }

        let members: [AppUser?] = await group.members.concurrentMap { userId in
            do {
                return try await self.fetchMemberBy(userId: userId)
            } catch {
                LogE("Failed to fetch member with userId: \(userId), error: \(error.localizedDescription)")
                return nil
            }
        }
        return members.compactMap { $0 }
    }

    public func removeMemberFrom(group: Groups, memberId: String) async throws {
        var group = group

        // Remove member from group
        group.members.removeAll(where: { $0 == memberId })

        // make group inactive if there are no members
        if group.members.isEmpty {
            group.isActive = false
        }

        // Change new admin if the old admin leaves the group
        if memberId == group.createdBy {
            // Create another top member as a new admin
            if let newAdmin = group.members.first {
                group.createdBy = newAdmin
            }
        }

        return try await updateGroup(group: group)
    }

    public func deleteGroup(group: Groups) async throws {
        var group = group

        // Make group inactive
        group.isActive = false

        return try await updateGroup(group: group)
    }
}
