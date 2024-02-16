//
//  OnboardViewModel.swift
//  UI
//
//  Created by Amisha Italiya on 13/02/24.
//

import Data
import FirebaseAuth
import Foundation

class OnboardViewModel: ObservableObject {
    
    @Published var currentPageIndex = 0
    
    let appRouter: Router<AppRoute>
    
    @Inject var preference: SplitoPreference
    
    init(appRouter: Router<AppRoute>) {
        self.appRouter = appRouter
    }
    
    func loginAnonymous() {
        Auth.auth().signInAnonymously { [weak self] result, error in
            guard let self, let user = result?.user else { return }
            let isAnonymous = user.isAnonymous
            self.preference.isOnboardShown = isAnonymous
            appRouter.push(.Login)
        }
    }
}
