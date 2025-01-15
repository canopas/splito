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
            let settings = FirestoreSettings()
            settings.cacheSettings = MemoryCacheSettings() // Disable cache by using an empty memory cache
            let db = Firestore.firestore()
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

        container.register(ActivityLogStore.self) { _ in
            ActivityLogStore.init()
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

        container.register(CommentStore.self) { _ in
            CommentStore.init()
        }.inObjectScope(.container)

        container.register(FeedbackStore.self) { _ in
            FeedbackStore.init()
        }.inObjectScope(.container)

        // MARK: - Repositories

        container.register(UserRepository.self) { _ in
            UserRepository.init()
        }.inObjectScope(.container)

        container.register(ActivityLogRepository.self) { _ in
            ActivityLogRepository.init()
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

        container.register(CommentRepository.self) { _ in
            CommentRepository.init()
        }.inObjectScope(.container)

        container.register(FeedbackRepository.self) { _ in
            FeedbackRepository.init()
        }.inObjectScope(.container)

        container.register(DeepLinkManager.self) { _ in
            DeepLinkManager()
        }.inObjectScope(.container)
    }
}
