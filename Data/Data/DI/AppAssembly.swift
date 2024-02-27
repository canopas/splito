//
//  AppAssembly.swift
//  Data
//
//  Created by Amisha Italiya on 16/02/24.
//

import Foundation
import Swinject

public class AppAssembly: Assembly {
    
    public init() { }
    
    public func assemble(container: Container) {
        
        container.register(Router<MainRoute>.self) { _ in
                .init(root: .Onboard)
        }.inObjectScope(.container)
        
        container.register(Router<AppRoute>.self) { _ in
                .init(root: .Home)
        }.inObjectScope(.container)
        
        container.register(SplitoPreference.self) { _ in
            SplitoPreference.init()
        }.inObjectScope(.container)
        
        container.register(DDLoggerProvider.self) { _ in
            DDLoggerProvider.init()
        }.inObjectScope(.container)
        
        container.register(FirestoreManager.self) { _ in
            FirestoreManager.init()
        }.inObjectScope(.container)
    }
}
