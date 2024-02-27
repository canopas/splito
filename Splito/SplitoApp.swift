//
//  SplitoApp.swift
//  Splito
//
//  Created by Amisha Italiya on 12/02/24.
//

import SwiftUI
import Data

@main
struct SplitoApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        Injector.shared.initInjector()
    }

    var body: some Scene {
        WindowGroup {
            MainRouteView()
        }
    }
}
