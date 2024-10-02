//
//  RouterView.swift
//  Data
//
//  Created by Amisha Italiya on 26/02/24.
//

import Foundation
import SwiftUI
import BaseStyle

public struct RouterView<T: Hashable, Content: View>: View {

    @StateObject var router: Router<T>

    @ViewBuilder var buildView: (T) -> Content

    public init(router: Router<T>, @ViewBuilder buildView: @escaping (T) -> Content) {
        self._router = .init(wrappedValue: router)
        self.buildView = buildView
    }

    public var body: some View {
        NavigationStack(path: $router.paths) {
            buildView(router.root)
                .navigationDestination(for: T.self) { path in
                    buildView(path)
                }
        }
        .tint(primaryText)
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

    public func popTo(_ path: T, inclusive: Bool = false) {
        if let index = paths.lastIndex(of: path) {
            let endIndex = inclusive ? index + 1 : index
            paths.removeSubrange(endIndex..<paths.endIndex)
        } else {
            LogD("Router: path not found.")
        }
    }
}
