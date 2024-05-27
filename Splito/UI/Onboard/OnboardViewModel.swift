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

class OnboardViewModel: BaseViewModel, ObservableObject {
    
    @Published var currentPageIndex = 0
    @Published private(set) var showLoader = false
    
    @Inject private var preference: SplitoPreference
    
    private let router: Router<AppRoute>
    
    init(router: Router<AppRoute>) {
        self.router = router
    }
    
    func loginAnonymous() {
        showLoader = true
        FirebaseProvider.auth.signInAnonymously { [weak self] result, error in
            guard let self = self else { return }
            if let error {
                self.showLoader = false
                self.alert = .init(message: "Server error")
                self.showAlert = true
            } else if let result {
                self.preference.isOnboardShown = result.user.isAnonymous
                self.showLoader = false
                router.updateRoot(root: .LoginView)
            } else {
                self.alert = .init(message: "Contact Support")
                self.showLoader = false
                self.showAlert = true
            }
            
        }
    }
}
