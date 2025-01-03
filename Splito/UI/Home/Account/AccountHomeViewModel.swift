//
//  AccountHomeViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 05/04/24.
//

import Data
import BaseStyle
import UIKit

class AccountHomeViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference

    @Published var currentState: ViewState = .initial
    @Published var showShareAppSheet = false

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()
    }

    func openUserProfileView() {
        router.push(.ProfileView)
    }

    func onContactSupportTap() {
        router.push(.FeedbackView)
    }

    func onRateAppTap() {
        let urlStr = Constants.rateAppURL // Open App Review Page
        guard let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func onShareAppTap() {
        showShareAppSheet = true
    }

    func dismissShareAppSheet() {
        showShareAppSheet = false
    }

    func handlePrivacyOptionTap() {
        if let url = URL(string: Constants.privacyPolicyURL) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:])
            } else {
                showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "Privacy policy cannot be accessed."))
            }
        }
    }

    func handleAcknowledgementsOptionTap() {
        if let url = URL(string: Constants.acknowledgementsURL) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:])
            } else {
                showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "Acknowledgements cannot be accessed."))
            }
        }
    }

    func handleLogoutBtnTap() {
        alert = .init(title: "See you soon!", message: "Are you sure you want to sign out?",
                      positiveBtnTitle: "Sign out",
                      positiveBtnAction: { [weak self] in self?.performLogoutAction() },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { [weak self] in self?.showAlert = false },
                      isPositiveBtnDestructive: true)
        showAlert = true
    }

    private func performLogoutAction() {
        do {
            currentState = .loading
            try FirebaseProvider.auth.signOut()
            preference.clearPreferenceSession()
        } catch let signOutError as NSError {
            currentState = .initial
            showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "Something went wrong."))
            LogE("AccountHomeViewModel: \(#function) Error signing out: \(signOutError)")
        }
    }
}

// MARK: - Group States
extension AccountHomeViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
