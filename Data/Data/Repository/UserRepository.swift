//
//  UserRepository.swift
//  Data
//
//  Created by Amisha Italiya on 26/02/24.
//

import Combine
import SwiftUI
import FirebaseAuth

public class UserRepository: ObservableObject {

    @Inject private var store: UserStore

    @Inject private var preference: SplitoPreference
    @Inject private var storageManager: StorageManager

    private var cancelable = Set<AnyCancellable>()

    public func storeUser(user: AppUser) -> AnyPublisher<AppUser, ServiceError> {
        store.fetchUsers()
            .flatMap { [weak self] users -> AnyPublisher<AppUser, ServiceError> in
                guard let self else {
                    return Fail(error: .unexpectedError).eraseToAnyPublisher()
                }

                if let searchedUser = users.first(where: { $0.id == user.id }) {
                    return Just(searchedUser).setFailureType(to: ServiceError.self).eraseToAnyPublisher()
                } else {
                    return self.store.addUser(user: user)
                        .mapError { error in
                            LogE("UserRepository :: \(#function) addUser failed, error: \(error.localizedDescription).")
                            return .databaseError
                        }
                        .map { _ in user }
                        .eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }

    public func fetchUserBy(userID: String) -> AnyPublisher<AppUser?, ServiceError> {
        store.fetchUsers()
            .map { users -> AppUser? in
                return users.first(where: { $0.id == userID })
            }
            .mapError { error -> ServiceError in
                LogE("UserRepository :: \(#function) fetchUserByID failed, error: \(error.localizedDescription).")
                return .databaseError
            }
            .eraseToAnyPublisher()
    }

    private func uploadImage(imageData: Data, user: AppUser) -> AnyPublisher<AppUser, ServiceError> {
        storageManager.uploadImage(for: .user, id: user.id, imageData: imageData)
            .flatMap { imageUrl -> AnyPublisher<AppUser, ServiceError> in
                var newUser = user
                newUser.imageUrl = imageUrl
                return self.updateUser(user: newUser)
            }
            .eraseToAnyPublisher()
    }

    public func updateUser(user: AppUser) -> AnyPublisher<AppUser, ServiceError> {
        store.updateUser(user: user)
    }

    public func updateUserWithImage(imageData: Data?, newImageUrl: String?, user: AppUser) -> AnyPublisher<AppUser, ServiceError> {
        var newUser = user

        if let currentUrl = user.imageUrl, newImageUrl == nil {
            newUser.imageUrl = newImageUrl

            return storageManager.deleteImage(imageUrl: currentUrl)
                .flatMap { _ in
                    self.performImageAction(imageData: imageData, user: newUser)
                }
                .eraseToAnyPublisher()
        } else {
            return self.performImageAction(imageData: imageData, user: newUser)
        }
    }

    private func performImageAction(imageData: Data?, user: AppUser) -> AnyPublisher<AppUser, ServiceError> {
        if let imageData {
            return self.uploadImage(imageData: imageData, user: user)
        } else {
            return updateUser(user: user)
        }
    }

    public func deleteUser(id: String) -> AnyPublisher<Void, ServiceError> {
        self.store.deactivateUserAfterDelete(userId: id)
            .flatMap { [weak self] _ -> AnyPublisher<Void, ServiceError> in
                guard let self else {
                    return Fail(error: .unexpectedError).eraseToAnyPublisher()
                }
                return deleteUserFromAuth()
            }
            .eraseToAnyPublisher()
    }

    private func deleteUserFromAuth() -> AnyPublisher<Void, ServiceError> {
        Future { promise in
            FirebaseProvider.auth.currentUser?.delete { error in
                if let error {
                    LogE("UserRepository :: \(#function): Deleting user from Auth failed with error: \(error.localizedDescription).")
                    promise(.failure(.deleteFailed(error: error.localizedDescription)))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
