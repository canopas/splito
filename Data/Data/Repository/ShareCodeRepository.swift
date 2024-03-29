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

    public func addSharedCode(sharedCode: SharedCode, completion: @escaping (String?) -> Void) {
        store.addSharedCode(sharedCode: sharedCode, completion: completion)
    }

    public func fetchSharedCode(code: String) -> Future<SharedCode?, ServiceError> {
        return store.fetchSharedCode(code: code.encryptHexCode())
    }

    public func deleteSharedCode(documentId: String) -> AnyPublisher<Void, ServiceError> {
        store.deleteSharedCode(documentId: documentId)
    }

    public func checkForCodeAvailability(code: String, completion: @escaping (Bool) -> Void) {
        fetchSharedCode(code: code)
            .sink { result in
                switch result {
                case .failure:
                    completion(true)
                case .finished:
                    return
                }
            } receiveValue: { code in
                completion(code == nil)
            }.store(in: &cancelable)
    }
}
