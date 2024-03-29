//
//  GroupStore.swift
//  Data
//
//  Created by Amisha Italiya on 16/03/24.
//

import Combine
import FirebaseFirestore

class GroupStore: ObservableObject {

    private let DATABASE_NAME: String = "groups"

    @Inject private var database: Firestore
    @Inject private var preference: SplitoPreference

    func createGroup(group: Groups, completion: @escaping (String?) -> Void) {
        do {
            let group = try database.collection(DATABASE_NAME).addDocument(from: group)
            completion(group.documentID)
            return
        } catch {
            LogE("GroupStore :: \(#function) error: \(error.localizedDescription)")
        }
        completion(nil)
    }

    func updateGroup(group: Groups) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self, let docID = group.id else {
                promise(.failure(.unexpectedError))
                return
            }
            do {
                try self.database.collection(self.DATABASE_NAME).document(docID).setData(from: group, merge: true)
                promise(.success(()))
            } catch {
                LogE("GroupStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError))
            }
        }.eraseToAnyPublisher()
    }

    func fetchGroups() -> AnyPublisher<[Groups], ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(DATABASE_NAME).getDocuments { snapshot, error in
                if let error {
                    LogE("GroupStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.unexpectedError))
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

            self.database.collection(DATABASE_NAME).document(id).getDocument { snapshot, error in
                if let error {
                    LogE("GroupStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.unexpectedError))
                    return
                }

                guard let snapshot else {
                    LogE("GroupStore :: \(#function) The document is not available.")
                    promise(.failure(.databaseError))
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
