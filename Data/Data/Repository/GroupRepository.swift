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
    @Inject private var storageManager: StorageManager
    @Inject private var memberRepository: MemberRepository

    private var cancelables = Set<AnyCancellable>()

    public func createGroup(group: Groups, imageData: Data?) -> AnyPublisher<String, ServiceError> {
        Future { [weak self] promise in

            guard let self else { return }

            self.createGroupInStore(group: group)
                .flatMap { docId -> AnyPublisher<(String, Member), ServiceError> in
                    return self.addCreatorToMembers(groupId: docId)
                        .map { (docId, $0) }
                        .eraseToAnyPublisher()
                }
                .flatMap { docId, member -> AnyPublisher<String, ServiceError> in
                    var newGroup = group
                    newGroup.id = docId
                    newGroup.members.append(member)
                    return self.finalizeGroupCreation(group: newGroup, imageData: imageData)
                }
                .sink { completion in
                    if case let .failure(error) = completion {
                        promise(.failure(error))
                    }
                } receiveValue: { docId in
                    promise(.success(docId))
                }
                .store(in: &self.cancelables)
        }
        .eraseToAnyPublisher()
    }

    private func createGroupInStore(group: Groups) -> AnyPublisher<String, ServiceError> {
        Future { [weak self] promise in

            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.store.createGroup(group: group) { docId in
                guard let docId else {
                    promise(.failure(.databaseError))
                    return
                }
                promise(.success(docId))
            }
        }.eraseToAnyPublisher()
    }

    private func addCreatorToMembers(groupId: String) -> AnyPublisher<Member, ServiceError> {
        Future { [weak self] promise in

            guard let self, let userId = self.preference.user?.id else { return }
            var member = Member(userId: userId, groupId: groupId)

            self.memberRepository.addMemberToMembers(member: member) { memberId in
                if let memberId {
                    member.id = memberId
                    promise(.success(member))
                } else {
                    promise(.failure(.databaseError))
                }
            }
        }.eraseToAnyPublisher()
    }

    private func finalizeGroupCreation(group: Groups, imageData: Data?) -> AnyPublisher<String, ServiceError> {
        Future { [weak self] promise in
            guard let self, let groupId = group.id else { return }
            if let imageData {
                self.uploadImage(imageData: imageData, group: group)
                    .sink { completion in
                        switch completion {
                        case .finished:
                            return
                        case .failure(let error):
                            promise(.failure(error))
                        }
                    } receiveValue: { _ in
                        promise(.success(groupId))
                    }.store(in: &self.cancelables)
            } else {
                self.updateGroup(group: group)
                    .sink { completion in
                        switch completion {
                        case .finished:
                            return
                        case .failure(let error):
                            promise(.failure(error))
                        }
                    } receiveValue: { _ in
                        promise(.success(groupId))
                    }.store(in: &self.cancelables)
            }
        }.eraseToAnyPublisher()
    }

    private func uploadImage(imageData: Data, group: Groups) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in

            guard let self, let groupId = group.id else {
                promise(.failure(.unexpectedError))
                return
            }

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
                    }.store(in: &self.cancelables)
            }
        }.eraseToAnyPublisher()
    }

    public func addMemberToGroup(groupId: String, memberId: String) -> AnyPublisher<String, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.fetchGroupBy(id: groupId)
                .flatMap { group -> AnyPublisher<(Groups?, Member?), ServiceError> in
                    return self.fetchMemberWith(id: memberId)
                        .map { (group, $0) }
                        .eraseToAnyPublisher()
                }
                .flatMap { group, member -> AnyPublisher<Void, ServiceError> in
                    guard var group, let member else {
                        return Fail(error: .dataNotFound).eraseToAnyPublisher()
                    }
                    group.members.append(member)
                    return self.updateGroup(group: group)
                }
                .sink { completion in
                    if case let .failure(error) = completion {
                        promise(.failure(error))
                    }
                } receiveValue: { _ in
                    promise(.success(groupId))
                }
                .store(in: &self.cancelables)
        }.eraseToAnyPublisher()
    }

    public func fetchMemberWith(id: String) -> AnyPublisher<Member?, ServiceError> {
        Future { [weak self] promise in
            guard let self else { return }
            self.memberRepository.fetchMemberBy(id: id)
                .sink { completion in
                    switch completion {
                    case .failure(let error):
                        promise(.failure(error))
                    case .finished:
                        break
                    }
                } receiveValue: { member in
                    promise(.success(member))
                }.store(in: &self.cancelables)
        }.eraseToAnyPublisher()
    }

    public func updateGroup(group: Groups) -> AnyPublisher<Void, ServiceError> {
        store.updateGroup(group: group)
    }

    public func fetchGroups(userId: String) -> AnyPublisher<[Groups], ServiceError> {
        store.fetchGroups(userId: userId)
    }

    public func fetchGroupBy(id: String) -> AnyPublisher<Groups?, ServiceError> {
        store.fetchGroupBy(id: id)
    }
}
