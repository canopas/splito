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

    private var cancelable = Set<AnyCancellable>()

    public func createGroup(group: Groups, imageData: Data?) -> AnyPublisher<String, ServiceError> {
        return store.createGroup(group: group)
            .flatMap { [weak self] groupId -> AnyPublisher<String, ServiceError> in
                guard let self else { return Fail(error: .unexpectedError).eraseToAnyPublisher() }
                guard let imageData else {
                    return Just(groupId).setFailureType(to: ServiceError.self).eraseToAnyPublisher()
                }

                var newGroup = group
                newGroup.id = groupId

                return self.uploadImage(imageData: imageData, group: newGroup)
                    .map { _ in groupId }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private func uploadImage(imageData: Data, group: Groups) -> AnyPublisher<Void, ServiceError> {
        guard let groupId = group.id else {
            return Fail(error: .unexpectedError).eraseToAnyPublisher()
        }

        return storageManager.uploadImage(for: .group, id: groupId, imageData: imageData)
            .flatMap { imageUrl -> AnyPublisher<Void, ServiceError> in
                var newGroup = group
                newGroup.imageUrl = imageUrl
                return self.updateGroup(group: newGroup)
            }
            .eraseToAnyPublisher()
    }

    public func updateGroupWithImage(imageData: Data?, newImageUrl: String?, group: Groups) -> AnyPublisher<Void, ServiceError> {
        var newGroup = group

        if let currentUrl = group.imageUrl, newImageUrl == nil {
            newGroup.imageUrl = newImageUrl

            return storageManager.deleteImage(imageUrl: currentUrl)
                .flatMap { _ in
                    self.performImageAction(imageData: imageData, group: newGroup)
                }
                .eraseToAnyPublisher()
        } else {
            return self.performImageAction(imageData: imageData, group: newGroup)
        }
    }

    private func performImageAction(imageData: Data?, group: Groups) -> AnyPublisher<Void, ServiceError> {
        if let imageData {
            self.uploadImage(imageData: imageData, group: group)
        } else {
            self.updateGroup(group: group)
        }
    }

    public func addMemberToGroup(groupId: String, memberId: String) -> AnyPublisher<Void, ServiceError> {
        store.addMemberToGroup(groupId: groupId, memberId: memberId)
    }

    public func updateGroup(group: Groups) -> AnyPublisher<Void, ServiceError> {
        store.updateGroup(group: group)
    }

    public func fetchGroupBy(id: String) -> AnyPublisher<Groups?, ServiceError> {
        store.fetchGroupBy(id: id)
    }

    public func fetchLatestGroupBy(id: String) -> AnyPublisher<Groups?, ServiceError> {
        store.fetchLatestGroupBy(id: id)
    }

    public func fetchGroupsBy(userId: String, limit: Int = 10, lastDocument: DocumentSnapshot? = nil) -> AnyPublisher<(groups: [Groups], lastDocument: DocumentSnapshot?), ServiceError> {
        store.fetchGroupsBy(userId: userId, limit: limit, lastDocument: lastDocument)
    }

    public func fetchMemberBy(userId: String) -> AnyPublisher<AppUser?, ServiceError> {
        userRepository.fetchUserBy(userID: userId)
    }

    public func fetchMembersBy(groupId: String) -> AnyPublisher<[AppUser], ServiceError> {
        fetchGroupBy(id: groupId)
            .flatMap { group -> AnyPublisher<[AppUser], ServiceError> in
                guard let group else {
                    return Fail(error: .dataNotFound).eraseToAnyPublisher()
                }

                // Create a publisher for each member ID and fetch user data
                let memberPublishers = group.members.map { (userId: String) -> AnyPublisher<AppUser?, ServiceError> in
                    return self.fetchMemberBy(userId: userId)
                }

                return Publishers.MergeMany(memberPublishers)
                    .compactMap { $0 }
                    .collect()
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    public func removeMemberFrom(group: Groups, memberId: String) -> AnyPublisher<Void, ServiceError> {
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

        return updateGroup(group: group)
    }

    public func deleteGroup(group: Groups) -> AnyPublisher<Void, ServiceError> {
        var group = group

        // Make group inactive
        group.isActive = false

        return updateGroup(group: group)
    }
}
