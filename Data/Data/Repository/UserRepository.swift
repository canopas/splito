//
//  UserRepository.swift
//  Data
//
//  Created by Amisha Italiya on 26/02/24.
//

import Combine

public class UserRepository: ObservableObject {

    @Inject private var store: UserStore

    private var cancelable = Set<AnyCancellable>()

    public func storeUser(user: AppUser) -> AnyPublisher<AppUser, ServiceError> {
        return self.store.fetchUsers()
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
                        .receive(on: DispatchQueue.main)
                        .eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }

    public func fetchUserBy(userID: String) -> AnyPublisher<AppUser?, ServiceError> {
        return self.store.fetchUsers()
            .map { users -> AppUser? in
                return users.first(where: { $0.id == userID })
            }
            .mapError { error -> ServiceError in
                LogE("UserRepository :: \(#function) fetchUserByID failed, error: \(error.localizedDescription).")
                return .databaseError
            }
            .eraseToAnyPublisher()
    }

    public func updateUser(user: AppUser) -> AnyPublisher<Void, ServiceError> {
        return store.updateUser(user: user)
    }

    public func deleteUser(id: String) -> AnyPublisher<Void, ServiceError> {
        return store.deleteUser(id: id)
    }
}
