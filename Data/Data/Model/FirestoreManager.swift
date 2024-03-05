//
//  FirestoreManager.swift
//  Data
//
//  Created by Amisha Italiya on 26/02/24.
//

import Combine
import FirebaseFirestore

public class FirestoreManager: ObservableObject {

    private let DATABASE_NAME: String = "Users"

    private let db = Firestore.firestore()

    public func addUser(user: AppUser) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self else { return }

            do {
                let document: () = try self.db.collection(self.DATABASE_NAME).document(user.id).setData(from: user)
                promise(.success(document))
            } catch {
                LogE("FirestoreManager :: \(#function) Encoding error: \(error.localizedDescription)")
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    public func updateUser(user: AppUser) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self else { return }

            do {
                let document: () = try self.db.collection(self.DATABASE_NAME).document(user.id).setData(from: user, merge: true)
                promise(.success(document))
            } catch {
                LogE("FirestoreManager :: \(#function) Encoding error: \(error.localizedDescription)")
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }

    public func deleteUser(id: String) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self else { return }

            self.db.collection(self.DATABASE_NAME).document(id).delete { error in
                if let error {
                    LogE("FirestoreManager :: \(#function): Deleting collection failed with error: \(error.localizedDescription).")
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }.eraseToAnyPublisher()
    }

    public func fetchUsers() -> AnyPublisher<[AppUser], ServiceError> {
        return Future { [weak self] promise in
            guard let self = self else { return }

            self.db.collection(self.DATABASE_NAME).getDocuments { (snapshot, error) in
                if let error {
                    LogE("FirestoreManager :: \(#function) error: \(error.localizedDescription)")
                    promise(.failure(.serverError()))
                    return
                }

                guard let snapshot else {
                    LogE("FirestoreManager :: \(#function) The document is not available.")
                    promise(.failure(.serverError())) // You can replace this with your own error type.
                    return
                }

                do {
                    var users: [AppUser] = []
                    for document in snapshot.documents {
                        let data = document.data()
                        let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                        let user = try JSONDecoder().decode(AppUser.self, from: jsonData)
                        users.append(user)
                    }
                    promise(.success(users))
                } catch {
                    LogE("FirestoreManager :: \(#function) Decode error: \(error.localizedDescription)")
                    promise(.failure(.serverError()))
                }
            }
        }.eraseToAnyPublisher()
    }
}
