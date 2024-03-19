//
//  GroupRepository.swift
//  Data
//
//  Created by Amisha Italiya on 07/03/24.
//

import Combine

public class GroupRepository: ObservableObject {

    @Inject private var store: GroupStore

    @Inject var preference: SplitoPreference
    @Inject var storageManager: StorageManager
    @Inject var memberRepository: MemberRepository

    private var cancelables = Set<AnyCancellable>()

    public func createGroup(group: Groups, imageData: Data?) -> AnyPublisher<String, ServiceError> {
        Future { [weak self] promise in

            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            var newGroup = group
            self.store.createGroup(group: group) { docId in
                guard let docId else {
                    promise(.failure(.databaseError))
                    return
                }

                newGroup.id = docId

                self.addCreatorToMembers(groupId: docId) { member in
                    guard let member else {
                        promise(.failure(.databaseError))
                        return
                    }
                    newGroup.members.append(member)

                    if let imageData {
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
                            }.store(in: &self.cancelables)
                    } else {
                        self.updateGroup(group: newGroup)
                            .sink { completion in
                                switch completion {
                                case .finished:
                                    return
                                case .failure(let error):
                                    promise(.failure(error))
                                }
                            } receiveValue: { _ in
                                promise(.success(docId))
                            }.store(in: &self.cancelables)
                    }
                }
            }
        }.eraseToAnyPublisher()
    }

    private func addCreatorToMembers(groupId: String, completion: @escaping (Member?) -> Void) {
        guard let userId = preference.user?.id else { return }

        var member = Member(userId: userId, groupId: groupId)

        memberRepository.addMemberToMembers(member: member) { id in
            member.id = id
            completion(id == nil ? nil : member)
        }
    }

    private func uploadImage(imageData: Data, group: Groups) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in

            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            if let groupId = group.id {
                storageManager.uploadImage(for: .group, id: groupId, imageData: imageData) { url in
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
                .sink { completion in
                    switch completion {
                    case .failure(let error):
                        promise(.failure(error))
                    case .finished:
                        return
                    }
                } receiveValue: { group in
                    guard let group else {
                        promise(.failure(.dataNotFound))
                        return
                    }

                    self.fetchMemberWith(id: memberId) { member in
                        if let member {
                            var newGroup = group
                            newGroup.members.append(member)

                            self.updateGroup(group: newGroup)
                                .sink { completion in
                                    switch completion {
                                    case .failure(let error):
                                        promise(.failure(error))
                                    case .finished:
                                        return
                                    }
                                } receiveValue: { _ in
                                    promise(.success((newGroup.id ?? "")))
                                }.store(in: &self.cancelables)
                        }
                    }
                }.store(in: &self.cancelables)
        }.eraseToAnyPublisher()
    }

    public func fetchMemberWith(id: String, completion: @escaping (Member?) -> Void) {
        memberRepository.fetchMemberBy(id: id)
            .sink { result in
                switch result {
                case .failure:
                    completion(nil)
                case .finished:
                    return
                }
            } receiveValue: { member in
                completion(member)
            }.store(in: &cancelables)
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
