//
//  AppRoute.swift
//  Data
//
//  Created by Amisha Italiya on 26/02/24.
//

import Foundation
import SwiftUI

public enum AppRoute: Equatable, Hashable {
    case OnboardView
    case LoginView
    case PhoneLoginView
    case VerifyOTPView(phoneNumber: String, verificationId: String)
    case Home
}

public struct RouterView<T: Hashable, Content: View>: View {

    @ObservedObject var router: Router<T>

    @ViewBuilder var buildView: (T) -> Content
    
    public init(router: Router<T>, @ViewBuilder buildView: @escaping (T) -> Content) {
        self.router = router
        self.buildView = buildView
    }

    public var body: some View {
        NavigationStack(path: $router.paths) {
            buildView(router.root)
                .navigationDestination(for: T.self) { path in
                    buildView(path)
                }
        }
        .environmentObject(router)
    }
}

public class Router<T: Hashable>: ObservableObject {

    @Published var root: T
    @Published var paths: [T] = []

    public init(root: T) {
        self.root = root
    }

    public func push(_ path: T) {
        paths.append(path)
    }

    public func pop() {
        paths.removeLast()
    }

    public func updateRoot(root: T) {
        self.root = root
    }

    public func popToRoot() {
        paths = []
    }
}
