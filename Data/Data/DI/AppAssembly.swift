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
        
        container.register(SplitoPreference.self) { _ in
            SplitoPreference.init()
        }.inObjectScope(.container)
        
        container.register(DDLoggerProvider.self) { _ in
            DDLoggerProvider.init()
        }.inObjectScope(.container)
        
    }
}
