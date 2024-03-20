//
//  UserRepository.swift
//  Data
//
//  Created by Amisha Italiya on 26/02/24.
//

import Combine

public class UserRepository: ObservableObject {

    @Inject private var store: UserStore

    private var cancelables = Set<AnyCancellable>()

    public func storeUser(user: AppUser) -> AnyPublisher<Void, ServiceError> {
        Future { [weak self] promise in

            guard let self else {
                promise(.failure(.unexpectedError))
                return
            }

            self.store.fetchUsers()
                .sink { completion in
                    switch completion {
                    case .finished:
                        LogE("UserRepository :: \(#function) storeUser finished.")
                    case .failure(let error):
                        LogE("UserRepository :: \(#function) storeUser failed, error: \(error.localizedDescription).")
                        promise(.failure(error))
                    }
                } receiveValue: { [weak self] users in
                    guard let self else { return }
                    let searchedUser = users.first(where: { $0.id == user.id })

                    if searchedUser != nil {
                        promise(.success(()))
                    } else {
                        self.store.addUser(user: user)
                            .receive(on: DispatchQueue.main)
                            .sink { completion in
                                switch completion {
                                case .failure(let error):
                                    LogE("UserRepository :: \(#function) addUser failed, error: \(error.localizedDescription).")
                                    promise(.failure(error))
                                case .finished:
                                    LogE("UserRepository :: \(#function) addUser finished.")
                                }
                            } receiveValue: { _ in
                                promise(.success(()))
                            }.store(in: &cancelables)
                    }
                }.store(in: &cancelables)
        }.eraseToAnyPublisher()
    }

    public func updateUser(user: AppUser) -> AnyPublisher<Void, ServiceError> {
        return store.updateUser(user: user)
    }

    public func deleteUser(id: String) -> AnyPublisher<Void, ServiceError> {
        return store.deleteUser(id: id)
    }
}
