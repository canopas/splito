//
//  UserStore.swift
//  Data
//
//  Created by Amisha Italiya on 16/03/24.
//

import Combine
import FirebaseFirestore

class UserStore: ObservableObject {

    private let DATABASE_NAME: String = "users"

    @Inject private var database: Firestore

    func addUser(user: AppUser) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            do {
                try self.database.collection(self.DATABASE_NAME).document(user.id).setData(from: user)
                promise(.success(()))
            } catch {
                LogE("UserStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError))
            }
        }.eraseToAnyPublisher()
    }

    func updateUser(user: AppUser) -> AnyPublisher<Void, ServiceError> {
        return Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            do {
                try self.database.collection(self.DATABASE_NAME).document(user.id).setData(from: user, merge: true)
                promise(.success(()))
            } catch {
                LogE("UserStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError))
            }
        }.eraseToAnyPublisher()
    }

    func deleteUser(id: String) -> AnyPublisher<Void, ServiceError> {
        return Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(self.DATABASE_NAME).document(id).delete { error in
                if let error {
                    LogE("UserStore :: \(#function): Deleting collection failed with error: \(error.localizedDescription).")
                    promise(.failure(.databaseError))
                } else {
                    promise(.success(()))
                }
            }
        }.eraseToAnyPublisher()
    }

    func fetchUsers() -> AnyPublisher<[AppUser], ServiceError> {
        return Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(self.DATABASE_NAME).getDocuments { snapshot, error in
                if let error {
                    LogE("UserStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.networkError))
                    return
                }

                guard let snapshot else {
                    LogE("UserStore :: \(#function) The document is not available.")
                    promise(.failure(.unexpectedError))
                    return
                }

                do {
                    let users = try snapshot.documents.compactMap { document in
                        try document.data(as: AppUser.self)
                    }
                    promise(.success(users))
                } catch {
                    LogE("UserStore :: \(#function) Decode error: \(error.localizedDescription)")
                    promise(.failure(.decodingError))
                }
            }
        }.eraseToAnyPublisher()
    }
}
