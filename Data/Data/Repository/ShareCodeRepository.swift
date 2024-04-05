//
//  ShareCodeRepository.swift
//  Data
//
//  Created by Amisha Italiya on 12/03/24.
//

import Combine

public class ShareCodeRepository: ObservableObject {

    public let CODE_EXPIRATION_LIMIT = 2 /// Limit for code expiration, in days.

    @Inject private var store: ShareCodeStore

    private var cancelable = Set<AnyCancellable>()

    public func addSharedCode(sharedCode: SharedCode) -> AnyPublisher<Void, ServiceError> {
        store.addSharedCode(sharedCode: sharedCode)
    }

    public func fetchSharedCode(code: String) -> Future<SharedCode?, ServiceError> {
        return store.fetchSharedCode(code: code.encryptHexCode())
    }

    public func deleteSharedCode(documentId: String) -> AnyPublisher<Void, ServiceError> {
        store.deleteSharedCode(documentId: documentId)
    }

    public func checkForCodeAvailability(code: String) -> AnyPublisher<Bool, ServiceError> {
        return Future { [weak self] promise in
            guard let self else { promise(.failure(.unexpectedError)); return }
            self.fetchSharedCode(code: code)
                .sink { result in
                    switch result {
                    case .failure(let error):
                        promise(.failure(error))
                    case .finished:
                        promise(.success(true))
                    }
                } receiveValue: { code in
                    promise(.success(code == nil))
                }.store(in: &self.cancelable)
        }
        .eraseToAnyPublisher()
    }
}
