//
//  OnboardViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 13/02/24.
//

import Data
import BaseStyle
import FirebaseAuth
import Foundation
import UIPilot

class OnboardViewModel: ObservableObject {

    @Published var currentPageIndex = 0
    @Published var currentState: ViewState = .initial

    @Inject private var preference: SplitoPreference

    private let router: UIPilot<AppRoute>

    init(router: UIPilot<AppRoute>) {
        self.router = router
    }

    func loginAnonymous() {
        currentState = .loading
        FirebaseProvider.auth.signInAnonymously { [weak self] result, _ in
            guard let self, let user = result?.user else { self?.currentState = .initial; return }
            self.preference.isOnboardShown = user.isAnonymous
            currentState = .initial

            router.popTo(.OnboardView, inclusive: true)
            router.push(.LoginView)
        }
    }
}

// MARK: - Group States
extension OnboardViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
