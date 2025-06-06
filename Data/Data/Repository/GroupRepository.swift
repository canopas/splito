//
//  GroupRepository.swift
//  Data
//
//  Created by Amisha Italiya on 07/03/24.
//

import SwiftUI
import FirebaseFirestore

public class GroupRepository: ObservableObject {

    @Inject private var store: GroupStore

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var storageManager: StorageManager
    @Inject private var codeRepository: ShareCodeRepository
    @Inject private var activityLogRepository: ActivityLogRepository

    private var olderGroupName: String = ""

    public func createGroup(group: Groups, imageData: Data?) async throws -> Groups {
        let groupDocument = try await store.getNewGroupDocument()

        var newGroup = group
        newGroup.id = groupDocument.documentID

        // If image data is provided, upload the image and update the group's imageUrl
        if let imageData = imageData {
            let imageUrl = try await uploadImage(imageData: imageData, group: newGroup)
            newGroup.imageUrl = imageUrl
        }

        try await store.createGroup(document: groupDocument, group: newGroup)
        try await logAddGroupActivity(group: newGroup, type: .groupCreated)

        return newGroup
    }

    private func logAddGroupActivity(group: Groups, type: ActivityType) async throws {
        guard let user = preference.user else { return }
        let context = ActivityLogContext(group: group, type: type, memberId: user.id, currentUser: user)
        if let error = await addActivityLog(context: context) {
            throw error
        }
    }

    public func updateGroupWithImage(imageData: Data?, newImageUrl: String?,
                                     group: Groups, oldGroupName: String) async throws -> Groups {
        var updatedGroup = group
        olderGroupName = oldGroupName

        // If image data is provided, upload the new image and update the imageUrl
        if let imageData {
            // Upload the image and get the new image URL
            let uploadedImageUrl = try await uploadImage(imageData: imageData, group: updatedGroup)
            updatedGroup.imageUrl = uploadedImageUrl
        } else if let currentUrl = group.imageUrl, newImageUrl == nil {
            // If there's a current image URL and we want to remove it, delete the image and set imageUrl empty
            try await storageManager.deleteAttachment(attachmentUrl: currentUrl)
            updatedGroup.imageUrl = ""
        } else if let newImageUrl = newImageUrl {
            // If a new image URL is explicitly passed, update it
            updatedGroup.imageUrl = newImageUrl
        }

        try await updateGroup(group: updatedGroup, type: getActivityType(oldGroup: group, updatedGroup: updatedGroup))
        return updatedGroup
    }

    private func getActivityType(oldGroup: Groups, updatedGroup: Groups) -> ActivityType {
        let imageChanged = oldGroup.imageUrl != updatedGroup.imageUrl
        let nameChanged = olderGroupName != updatedGroup.name

        if imageChanged && nameChanged { return .groupUpdated }
        if imageChanged { return .groupImageUpdated }
        if nameChanged { return .groupNameUpdated }
        return .none
    }

    private func uploadImage(imageData: Data, group: Groups) async throws -> String {
        guard let groupId = group.id else { return "" }

        // Upload the image and get the image URL
        return try await storageManager.uploadAttachment(for: .group, id: groupId, attachmentData: imageData) ?? ""
    }

    public func addMemberToGroup(groupId: String, memberId: String) async throws {
        try await store.addMemberToGroup(groupId: groupId, memberId: memberId)
    }

    public func removeMemberFrom(group: Groups, removedMember: AppUser) async throws {
        guard let userId = preference.user?.id else { return }
        var group = group

        // make group inactive if there are no members
        if group.members.isEmpty {
            group.isActive = false
        }

        // Change new admin if the old admin leaves the group
        if removedMember.id == group.createdBy {
            // Create another top member as a new admin
            if let newAdmin = group.members.first(where: { $0 != removedMember.id }) {
                group.createdBy = newAdmin
            }
        }

        let activityType: ActivityType = userId == removedMember.id ? .groupMemberLeft : .groupMemberRemoved
        try await updateGroup(group: group, type: activityType, removedMember: removedMember)
    }

    public func deleteGroup(group: Groups) async throws {
        guard let userId = preference.user?.id else { return }

        var group = group
        group.isActive = false  // Make group inactive
        group.updatedBy = userId
        group.updatedAt = Timestamp()

        try await updateGroup(group: group, type: .groupDeleted)
    }

    public func updateGroup(group: Groups, type: ActivityType, removedMember: AppUser? = nil) async throws {
        var updatedgroup = group
        updatedgroup.members.removeAll(where: { $0 == removedMember?.id }) // Remove member from group

        try await store.updateGroup(group: updatedgroup)
        try await addActivityLogForGroup(type: type, group: group, removedMember: removedMember)
    }

    private func addActivityLogForGroup(type: ActivityType, group: Groups, removedMember: AppUser? = nil) async throws {
        guard let user = preference.user, type != .none else { return }
        var throwableError: Error?

        await withTaskGroup(of: Error?.self) { taskGroup in
            for memberId in group.members {
                taskGroup.addTask { [weak self] in
                    guard let self else { return nil }
                    let removedMemberName = (type == .groupMemberRemoved ? (memberId == removedMember?.id) ? "you" : removedMember?.nameWithLastInitial : nil)

                    let context = ActivityLogContext(group: group, type: type, memberId: memberId, currentUser: user,
                                                     previousGroupName: olderGroupName, removedMemberName: removedMemberName)
                    return await self.addActivityLog(context: context)
                }
            }

            for await error in taskGroup {
                if let error {
                    throwableError = error
                    taskGroup.cancelAll()
                    break
                }
            }
        }

        if let throwableError {
            throw throwableError
        }
    }

    private func createActivityLogForGroup(context: ActivityLogContext) -> ActivityLog? {
        guard let groupId = context.group?.id, let memberId = context.memberId,
              let currentUser = context.currentUser else { return nil }

        let actionUserName = memberId == currentUser.id ? "You" : currentUser.nameWithLastInitial

        return ActivityLog(type: context.type, groupId: groupId, activityId: groupId,
                           groupName: context.group?.name ?? "", actionUserName: actionUserName,
                           recordedOn: Timestamp(date: Date()), previousGroupName: context.previousGroupName,
                           removedMemberName: context.removedMemberName)
    }

    private func addActivityLog(context: ActivityLogContext) async -> Error? {
        if let activity = createActivityLogForGroup(context: context), let memberId = context.memberId {
            do {
                try await activityLogRepository.addActivityLog(userId: memberId, activity: activity)
                LogD("GroupRepository: \(#function) Activity log added successfully for \(memberId).")
            } catch {
                LogE("GroupRepository: \(#function) Failed to add activity log for \(memberId): \(error).")
                return error
            }
        }
        return nil
    }

    public func fetchGroupBy(id: String) async throws -> Groups? {
        try await store.fetchGroupBy(id: id)
    }

    public func streamLatestGroupDataBy(id: String) -> AsyncStream<Groups?> {
        store.streamLatestGroupBy(id: id)
    }

    public func fetchGroupsBy(userId: String, limit: Int = 10, lastDocument: DocumentSnapshot? = nil) async throws -> (data: [Groups], lastDocument: DocumentSnapshot?) {
        try await store.fetchGroupsBy(userId: userId, limit: limit, lastDocument: lastDocument)
    }

    public func fetchUsersActiveGroups(userId: String) async throws -> [Groups] {
        try await store.fetchUsersActiveGroups(userId: userId)
    }

    public func fetchMemberBy(memberId: String) async throws -> AppUser? {
        try await userRepository.fetchUserBy(userID: memberId)
    }

    public func fetchMembersBy(memberIds: [String]) async throws -> [AppUser] {
        var members: [AppUser] = []

        try await withThrowingTaskGroup(of: AppUser?.self) { [weak self] groupTask in
            for memberId in memberIds {
                groupTask.addTask {
                    try await self?.fetchMemberBy(memberId: memberId)
                }
            }

            for try await member in groupTask {
                if let member {
                    members.append(member)
                }
            }
        }

        return members
    }
}
