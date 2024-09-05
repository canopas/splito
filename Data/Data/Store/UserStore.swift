//
//  UserStore.swift
//  Data
//
//  Created by Amisha Italiya on 16/03/24.
//

import Combine
import FirebaseFirestore

class UserStore: ObservableObject {

    private let COLLECTION_NAME: String = "users"

    @Inject private var database: Firestore

    func addUser(user: AppUser) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            do {
                try self.database.collection(self.COLLECTION_NAME).document(user.id).setData(from: user)
                promise(.success(()))
            } catch {
                LogE("UserStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError(error: error.localizedDescription)))
            }
        }.eraseToAnyPublisher()
    }

    func updateUser(user: AppUser) -> AnyPublisher<AppUser, ServiceError> {
        Future<AppUser, ServiceError> { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            do {
                try self.database.collection(self.COLLECTION_NAME).document(user.id).setData(from: user, merge: true)
                promise(.success(user))
            } catch {
                LogE("UserStore :: \(#function) error: \(error.localizedDescription)")
                promise(.failure(.databaseError(error: error.localizedDescription)))
            }
        }.eraseToAnyPublisher()
    }

    func fetchUserBy(id: String) -> AnyPublisher<AppUser?, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(self.COLLECTION_NAME).document(id).getDocument { snapshot, error in
                if let error {
                    LogE("UserStore :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.databaseError(error: error.localizedDescription)))
                    return
                }

                guard let snapshot else {
                    LogE("UserStore :: \(#function) The document is not available.")
                    promise(.failure(.dataNotFound))
                    return
                }

                do {
                    let user = try snapshot.data(as: AppUser.self)
                    promise(.success(user))
                } catch {
                    print("USERID: \(id)")
                    LogE("UserStore :: \(#function) Decode error: \(error.localizedDescription)")
                    promise(.failure(.decodingError))
                }
            }
        }.eraseToAnyPublisher()
    }

    func deactivateUserAfterDelete(userId: String) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in
            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.database.collection(self.COLLECTION_NAME)
                .document(userId)
                .updateData(["is_active": false]) { error in
                    if let error {
                        LogE("UserStore :: \(#function): Deleting user from Auth failed with error: \(error.localizedDescription).")
                        promise(.failure(.deleteFailed(error: error.localizedDescription)))
                    } else {
                        promise(.success(()))
                    }
                }
        }.eraseToAnyPublisher()
    }
}
