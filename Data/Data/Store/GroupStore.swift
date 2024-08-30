//
//  GroupStore.swift
//  Data
//
//  Created by Amisha Italiya on 16/03/24.
//

import Combine
import FirebaseFirestore

class GroupStore: ObservableObject {

    private let COLLECTION_NAME: String = "groups"

    @Inject private var database: Firestore
    @Inject private var preference: SplitoPreference

    func createGroup(group: Groups) -> AnyPublisher<String, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            do {
                let documentRef = try self.database.collection(self.COLLECTION_NAME).addDocument(from: group)
                promise(.success(documentRef.documentID))
            } catch {
                LogE("GroupStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError(error: error.localizedDescription)))
            }
        }
        .eraseToAnyPublisher()
    }

    func addMemberToGroup(groupId: String, memberId: String) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            let groupRef = self.database.collection(self.COLLECTION_NAME).document(groupId)

            do {
                let memberBalance = GroupMemberBalance(id: memberId, balance: 0, totalSummary: [])
                let memberBalanceData = try Firestore.Encoder().encode(memberBalance)

                groupRef.updateData([
                    "members": FieldValue.arrayUnion([memberId]),
                    "balance": FieldValue.arrayUnion([memberBalanceData])
                ]) { error in
                    if let error {
                        LogE("GroupStore :: \(#function) error: \(error.localizedDescription)")
                        promise(.failure(.databaseError(error: error.localizedDescription)))
                    } else {
                        promise(.success(()))
                    }
                }
            } catch {
                LogE("GroupStore :: \(#function) error encoding balance: \(error.localizedDescription)")
                promise(.failure(.unexpectedError))
            }
        }.eraseToAnyPublisher()
    }

    func updateGroup(group: Groups) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self, let groupId = group.id else {
                promise(.failure(.unexpectedError))
                return
            }
            do {
                try self.database.collection(self.COLLECTION_NAME).document(groupId).setData(from: group, merge: false)
                promise(.success(()))
            } catch {
                LogE("GroupStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError(error: error.localizedDescription)))
            }
        }.eraseToAnyPublisher()
    }

    func fetchLatestGroups(userId: String) -> AnyPublisher<[Groups], ServiceError> {
        database.collection(COLLECTION_NAME)
            .whereField("is_active", isEqualTo: true)
            .whereField("members", arrayContains: userId)
            .limit(to: 10)
            .snapshotPublisher(as: Groups.self)
    }

    func fetchGroupsBy(userId: String) -> AnyPublisher<[Groups], ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(COLLECTION_NAME)
                .whereField("is_active", isEqualTo: true)
                .whereField("members", arrayContains: userId)
                .getDocuments { snapshot, error in
                    if let error {
                        LogE("GroupStore :: \(#function) error: \(error.localizedDescription)")
                        promise(.failure(.databaseError(error: error.localizedDescription)))
                        return
                    }

                    guard let snapshot, !snapshot.documents.isEmpty else {
                        LogD("GroupStore :: \(#function) The document is not available.")
                        promise(.success([]))
                        return
                    }

                    do {
                        let groups = try snapshot.documents.compactMap { document in
                            try document.data(as: Groups.self)
                        }
                        promise(.success(groups))
                    } catch {
                        LogE("GroupStore :: \(#function) Decode error: \(error.localizedDescription)")
                        promise(.failure(.decodingError))
                    }
                }
        }.eraseToAnyPublisher()
    }

    func fetchGroupBy(id: String) -> AnyPublisher<Groups?, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(COLLECTION_NAME).document(id).getDocument { snapshot, error in
                if let error {
                    LogE("GroupStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError(error: error.localizedDescription)))
                    return
                }

                guard let snapshot else {
                    LogE("GroupStore :: \(#function) The document is not available.")
                    promise(.failure(.dataNotFound))
                    return
                }

                do {
                    let group = try snapshot.data(as: Groups.self)
                    promise(.success(group))
                } catch {
                    LogE("GroupStore :: \(#function) Decode error: \(error.localizedDescription)")
                    promise(.failure(.decodingError))
                }
            }
        }.eraseToAnyPublisher()
    }
}
