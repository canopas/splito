//
//  AppAssembly.swift
//  Data
//
//  Created by Amisha Italiya on 16/02/24.
//

import Foundation
import Swinject
import FirebaseFirestore

public class AppAssembly: Assembly {

    public init() { }

    public func assemble(container: Container) {

        container.register(SplitoPreference.self) { _ in
            SplitoPreference.init()
        }.inObjectScope(.container)

        container.register(DDLoggerProvider.self) { _ in
            DDLoggerProvider.init()
        }.inObjectScope(.container)

        container.register(Firestore.self) { _ in
            let db = Firestore.firestore()
            let settings = FirestoreSettings()
            settings.isPersistenceEnabled = false
            db.settings = settings
            return db
        }.inObjectScope(.container)

        container.register(StorageManager.self) { _ in
            StorageManager.init()
        }.inObjectScope(.container)

        // MARK: - Stores

        container.register(UserStore.self) { _ in
            UserStore.init()
        }.inObjectScope(.container)

        container.register(GroupStore.self) { _ in
            GroupStore.init()
        }.inObjectScope(.container)

        container.register(ShareCodeStore.self) { _ in
            ShareCodeStore.init()
        }.inObjectScope(.container)

        container.register(ExpenseStore.self) { _ in
            ExpenseStore.init()
        }.inObjectScope(.container)

        container.register(TransactionStore.self) { _ in
            TransactionStore.init()
        }.inObjectScope(.container)

        // MARK: - Repositories

        container.register(UserRepository.self) { _ in
            UserRepository.init()
        }.inObjectScope(.container)

        container.register(GroupRepository.self) { _ in
            GroupRepository.init()
        }.inObjectScope(.container)

        container.register(ShareCodeRepository.self) { _ in
            ShareCodeRepository.init()
        }.inObjectScope(.container)

        container.register(ExpenseRepository.self) { _ in
            ExpenseRepository.init()
        }.inObjectScope(.container)

        container.register(TransactionRepository.self) { _ in
            TransactionRepository.init()
        }.inObjectScope(.container)
    }
}
