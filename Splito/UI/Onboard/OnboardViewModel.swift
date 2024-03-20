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

    @Inject var preference: SplitoPreference

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
    }

    func loginAnonymous() {
        Auth.auth().signInAnonymously { [weak self] result, _ in
            guard let self, let user = result?.user else { return }
            let isAnonymous = user.isAnonymous
            self.preference.isOnboardShown = isAnonymous
            router.updateRoot(root: .LoginView)
        }
    }
}
