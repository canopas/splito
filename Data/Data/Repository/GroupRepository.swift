//
//  GroupRepository.swift
//  Data
//
//  Created by Amisha Italiya on 07/03/24.
//

import Combine

public class GroupRepository: ObservableObject {

    @Inject private var store: GroupStore

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var storageManager: StorageManager

    private var cancelable = Set<AnyCancellable>()

    public func createGroup(group: Groups, imageData: Data?) -> AnyPublisher<String, ServiceError> {
        Future { [weak self] promise in
            guard let self else { promise(.failure(.unexpectedError)); return }

            self.store.createGroup(group: group) { docId in
                guard let docId else {
                    promise(.failure(.databaseError))
                    return
                }

                if let imageData {
                    var newGroup = group
                    newGroup.id = docId
                    self.uploadImage(imageData: imageData, group: newGroup)
                        .sink { completion in
                            switch completion {
                            case .finished:
                                return
                            case .failure(let error):
                                promise(.failure(error))
                            }
                        } receiveValue: { _ in
                            promise(.success(docId))
                        }.store(in: &self.cancelable)
                } else {
                    promise(.success(docId))
                }
            }
        }.eraseToAnyPublisher()
    }

    public func fetchGroupBy(id: String) -> AnyPublisher<Groups?, ServiceError> {
        store.fetchGroupBy(id: id)
    }

    public func fetchGroups(userId: String) -> AnyPublisher<[Groups], ServiceError> {
        Future { [weak self] promise in
            guard let self else { return }

            self.store.fetchGroups()
                .sink { completion in
                    if case .failure(let error) = completion {
                        promise(.failure(error))
                    }
                } receiveValue: { groups in
                    // Show only those groups in which the user is part of
                    let filteredGroups = groups.filter { $0.createdBy == userId || $0.members.contains { $0 == userId } }
                    promise(.success(filteredGroups))
                }.store(in: &self.cancelable)
        }.eraseToAnyPublisher()
    }

    public func addMemberToGroup(memberId: String, groupId: String) -> AnyPublisher<Void, ServiceError> {
        return fetchGroupBy(id: groupId)
            .flatMap { group -> AnyPublisher<Void, ServiceError> in
                guard let group else { return Fail(error: .dataNotFound).eraseToAnyPublisher() }

                var newGroup = group
                newGroup.members.append(memberId)

                return self.updateGroup(group: newGroup)
            }
            .eraseToAnyPublisher()
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
                    .mapError { $0 }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    public func fetchMemberBy(userId: String) -> AnyPublisher<AppUser?, ServiceError> {
        userRepository.fetchUserBy(userID: userId)
    }

    public func updateGroup(group: Groups) -> AnyPublisher<Void, ServiceError> {
        store.updateGroup(group: group)
    }

    private func uploadImage(imageData: Data, group: Groups) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in

            guard let self, let groupId = group.id else { promise(.failure(.unexpectedError)); return }

            self.storageManager.uploadImage(for: .group, id: groupId, imageData: imageData) { url in
                guard let url else {
                    promise(.failure(.databaseError))
                    return
                }

                var newGroup = group
                newGroup.imageUrl = url

                self.updateGroup(group: newGroup)
                    .sink { completion in
                        switch completion {
                        case .finished:
                            return
                        case .failure(let error):
                            promise(.failure(error))
                        }
                    } receiveValue: { _ in
                        promise(.success(()))
                    }.store(in: &self.cancelable)
            }
        }.eraseToAnyPublisher()
    }
}
