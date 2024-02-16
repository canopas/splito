//
//  Injector.swift
//  Data
//
//  Created by Amisha Italiya on 16/02/24.
//

import Foundation
import Swinject

public class Injector {
    fileprivate var appAssembler: Assembler!

    private init() {}

    public static let shared = Injector()

    public func initInjector() {
        appAssembler = Assembler([AppAssembly()])
    }

    public func setTestAassembler(assemblies: [Assembly]) {
        appAssembler = Assembler(assemblies)
    }
}

public func appResolve<S>(serviceType: S.Type) -> S {
    Injector.shared.appAssembler.resolver.resolve(serviceType)!
}

@propertyWrapper
public struct Inject<Component> {

    private var component: Component

    public init() {
        self.component = appResolve(serviceType: Component.self)
    }

    public var wrappedValue: Component {
        get { return component}
        mutating set { component = newValue }
    }
}
