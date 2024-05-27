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

class OnboardViewModel: ObservableObject {

    @Published var currentPageIndex = 0
    @Published private(set) var showLoader = false

    @Inject private var preference: SplitoPreference

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
    }

    func loginAnonymous() {
        showLoader = true
        FirebaseProvider.auth.signInAnonymously { [weak self] result, _ in
            guard let self, let user = result?.user else { self?.showLoader = false; return }
            self.preference.isOnboardShown = user.isAnonymous
            showLoader = false
            router.updateRoot(root: .LoginView)
        }
    }
}
