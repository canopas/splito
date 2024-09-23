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

    public func createGroup(group: Groups, imageData: Data?) async throws -> String? {
        let groupId = try await store.createGroup(group: group)

        if let imageData {
            var newGroup = group
            newGroup.id = groupId
            try await uploadImage(imageData: imageData, group: newGroup)
        }

        return groupId
    }

    private func uploadImage(imageData: Data, group: Groups) async throws {
        guard let groupId = group.id else { return }

        let imageUrl = try await storageManager.uploadImage(for: .group, id: groupId, imageData: imageData)

        var newGroup = group
        newGroup.imageUrl = imageUrl

        try await updateGroup(group: newGroup)
    }

    public func updateGroupWithImage(imageData: Data?, newImageUrl: String?, group: Groups) async throws -> Groups {
        var newGroup = group

        // Check if the group has an existing image URL and the new image URL is nil (deletion case)
        if let currentUrl = group.imageUrl, newImageUrl == nil {
            newGroup.imageUrl = newImageUrl
            try await storageManager.deleteImage(imageUrl: currentUrl)
            try await self.performImageAction(imageData: imageData, group: newGroup)
            return newGroup
        } else if let newImageUrl = newImageUrl {
            // If there's a new image URL, update the group with the new image URL
            newGroup.imageUrl = newImageUrl
            try await self.performImageAction(imageData: imageData, group: newGroup)
            return newGroup
        } else {
            // If no changes are made to the image URL, return the group as it is
            return newGroup
        }
    }

    private func performImageAction(imageData: Data?, group: Groups) async throws {
        if let imageData {
            try await uploadImage(imageData: imageData, group: group)
        } else {
            try await updateGroup(group: group)
        }
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
