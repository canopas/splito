//
//  OnboardViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 13/02/24.
//

import Data
import BaseStyle
import Foundation

class OnboardViewModel: BaseViewModel, ObservableObject {

    @Published var currentPageIndex = 0

    @Inject private var preference: SplitoPreference

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
    }

    func handleGetStartedAction() {
        preference.isOnboardShown = true
        router.updateRoot(root: .LoginView)
    }
}
