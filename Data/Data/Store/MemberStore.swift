//
//  MemberStore.swift
//  Data
//
//  Created by Amisha Italiya on 16/03/24.
//

import Combine
import FirebaseFirestoreInternal

class MemberStore: ObservableObject {

    private let DATABASE_NAME: String = "members"

    @Inject private var database: Firestore

    func addMember(member: Member, completion: @escaping (String?) -> Void) {
        do {
            let member = try database.collection(DATABASE_NAME).addDocument(from: member)
            completion(member.documentID)
            return
        } catch {
            LogE("MemberStore :: \(#function) error: \(error.localizedDescription)")
        }
        completion(nil)
    }

    func updateMember(member: Member) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self, let docID = member.id else {
                promise(.failure(.unexpectedError))
                return
            }
            do {
                try self.database.collection(self.DATABASE_NAME).document(docID).setData(from: member, merge: true)
                promise(.success(()))
            } catch {
                LogE("MemberStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError))
            }
        }.eraseToAnyPublisher()
    }

    func fetchMemberBy(id: String) -> AnyPublisher<Member?, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(DATABASE_NAME).document(id).getDocument { snapshot, error in
                if let error {
                    LogE("MemberStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.unexpectedError))
                    return
                }

                guard let snapshot else {
                    LogE("MemberStore :: \(#function) The document is not available.")
                    promise(.failure(.databaseError))
                    return
                }

                do {
                    let member = try snapshot.data(as: Member.self)
                    promise(.success(member))
                } catch {
                    LogE("MemberStore :: \(#function) Decode error: \(error.localizedDescription)")
                    promise(.failure(.decodingError))
                }
            }
        }.eraseToAnyPublisher()
    }

    func fetchMembers() -> AnyPublisher<[Member], ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(DATABASE_NAME).getDocuments { snapshot, error in
                if let error {
                    LogE("MemberStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.unexpectedError))
                    return
                }

                guard let snapshot else {
                    LogE("MemberStore :: \(#function) The document is not available.")
                    promise(.failure(.databaseError))
                    return
                }

                do {
                    let members = try snapshot.documents.compactMap { document -> Member? in
                        try document.data(as: Member.self)
                    }
                    promise(.success(members))
                } catch {
                    LogE("MemberStore :: \(#function) Decode error: \(error.localizedDescription)")
                    promise(.failure(.decodingError))
                }
            }
        }.eraseToAnyPublisher()
    }

    func fetchMembersByGroup(id: String) -> AnyPublisher<[Member], ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            // Construct a Firestore query to fetch documents where group_id matches the provided groupId
            self.database.collection(DATABASE_NAME)
                .whereField("group_id", isEqualTo: id)
                .getDocuments { snapshot, error in
                    if let error {
                        LogE("MemberStore :: \(#function) error: \(error.localizedDescription)")
                        promise(.failure(.unexpectedError))
                        return
                    }

                    guard let snapshot else {
                        LogE("MemberStore :: \(#function) The document is not available.")
                        promise(.failure(.databaseError))
                        return
                    }

                    do {
                        let members = try snapshot.documents.compactMap { document -> Member? in
                            try document.data(as: Member.self)
                        }
                        promise(.success(members))
                    } catch {
                        LogE("MemberStore :: \(#function) Decode error: \(error.localizedDescription)")
                        promise(.failure(.decodingError))
                    }
                }
        }.eraseToAnyPublisher()
    }
}
