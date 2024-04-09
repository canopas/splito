//
//  AccountHomeViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 05/04/24.
//

import Data
import MessageUI
import BaseStyle

class AccountHomeViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var userRepository: UserRepository
    @Inject private var ddLoggerProvider: DDLoggerProvider

    @Published var currentState: ViewState = .initial

    @Published var logFilePath: URL?
    @Published var showShareSheet = false
    @Published var showMailToast = false

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()
    }

    func openUserProfileView() {
        router.push(.ProfileView)
    }

    func onContactUsTap() {
        guard MFMailComposeViewController.canSendMail() else {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Warning", message: "Your device cannot send email."))
            showMailToast = true
            return
        }
        let logger = ddLoggerProvider.provideLogger()
        logger.removeAllZipLogs()
        logFilePath = logger.zipLogs()
        showShareSheet = true
    }

    func showMailSendToast() {
        showToastFor(toast: ToastPrompt(type: .success, title: "Success", message: "Email sent successfully!"))
        showMailToast = true
    }

    func onRateAppTap() {

    }

    func performLogoutAction() {

    }
}

// MARK: - Group States
extension AccountHomeViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
