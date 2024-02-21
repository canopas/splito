//
//  LogInRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 16/02/24.
//

import Foundation
import SwiftUI
import BaseStyle

enum AppRoute {

    case LoginView
//    case PhoneLoginView
//    case VerifyOTPView

}

public struct LogInRouteView: View {

    var router = Router<AppRoute>(root: .LoginView)

    public var body: some View {
        RouterView(router: router) { route in
            switch route {
            case .LoginView:
                LoginView(viewModel: LoginViewModel())
            }
        }
    }
}
