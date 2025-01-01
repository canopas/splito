//
//  OnboardViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 13/02/24.
//

import Data
import BaseStyle
import SwiftUI

class OnboardViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference

    @Published var currentPageIndex = 0
    @Published private(set) var showGetStartedButton = false

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
    }

    func handleGetStartedAction() {
        preference.isOnboardShown = true
        router.updateRoot(root: .LoginView)
    }

    func handleGetStartedBtnVisibility(isLastIndex: Bool) {
        if isLastIndex {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                withAnimation {
                    self?.showGetStartedButton = true
                }
            }
        } else {
            withAnimation { [weak self] in
                self?.showGetStartedButton = false
            }
        }
    }
}
