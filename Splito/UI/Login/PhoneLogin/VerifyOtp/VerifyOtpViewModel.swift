//
//  VerifyOtpViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 23/02/24.
//

import Data
import SwiftUI
import Combine
import FirebaseAuth

public class VerifyOtpViewModel: BaseViewModel, ObservableObject {

    @Published var otp = ""
    @Published var resendOtpCount: Int = 30

    @Published private(set) var showLoader: Bool = false

    @Inject var preference: SplitoPreference
    @Inject var userRepository: UserRepository

    var resendTimer: Timer?
    var phoneNumber: String
    var verificationId: String

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>, phoneNumber: String, verificationId: String) {
        self.router = router
        self.phoneNumber = phoneNumber
        self.verificationId = verificationId
        super.init()
        runTimer()
    }

    func verifyOTP() {
        guard !otp.isEmpty else { return }

        let credential = FirebaseProvider.phoneAuthProvider.credential(withVerificationID: verificationId, verificationCode: otp)
        showLoader = true
        FirebaseProvider.auth.signIn(with: credential) {[weak self] (result, _) in
            self?.showLoader = false
            if let result {
                self?.resendTimer?.invalidate()
                let user = AppUser(id: result.user.uid, firstName: nil, lastName: nil, emailId: nil, phoneNumber: result.user.phoneNumber, loginType: .Phone)
                self?.storeUser(user: user)
            } else {
                self?.onLoginError()
            }
        }
    }

    func resendOtp() {
        showLoader = true
        FirebaseProvider.phoneAuthProvider.verifyPhoneNumber((phoneNumber), uiDelegate: nil) { [weak self] (verificationID, error) in
            guard let self else { return }
            self.showLoader = false
            if error != nil {
                if (error! as NSError).code == FirebaseAuth.AuthErrorCode.webContextCancelled.rawValue {
                    self.showAlertFor(message: "Something went wrong! Please try after some time.")
                } else if (error! as NSError).code == FirebaseAuth.AuthErrorCode.tooManyRequests.rawValue {
                    self.showAlertFor(title: "Warning !!!", message: "Too many attempts, please try after some time.")
                } else if (error! as NSError).code == FirebaseAuth.AuthErrorCode.missingPhoneNumber.rawValue || (error! as NSError).code == FirebaseAuth.AuthErrorCode.invalidPhoneNumber.rawValue {
                    self.showAlertFor(message: "Enter a valid phone number")
                } else {
                    LogE("Firebase: Phone login fail with error: \(error.debugDescription)")
                    self.showAlertFor(title: "Authentication failed", message: "Apologies, we were not able to complete the authentication process. Please try again later.")
                }
            } else {
                self.verificationId = verificationID ?? ""
                self.runTimer()
            }
        }
    }
}

// MARK: - Helper Methods
extension VerifyOtpViewModel {
    private func runTimer() {
        resendOtpCount = 30
        resendTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(update), userInfo: nil, repeats: true)
    }

    @objc func update() {
        if resendOtpCount > 0 {
            resendOtpCount -= 1
        } else {
            resendTimer?.invalidate()
        }
    }

    private func onLoginError() {
        showAlertFor(title: "Invalid OTP", message: "Please, enter a valid OTP code.")
    }

    private func storeUser(user: AppUser) {
        userRepository.storeUser(user: user)
            .sink { [weak self] completion in
                guard let self else { return }
                switch completion {
                case .failure(let error):
                    self.alert = .init(message: error.localizedDescription)
                    self.showAlert = true
                case .finished:
                    self.preference.isVerifiedUser = true
                }
            } receiveValue: { [weak self] user in
                guard let self else { return }
                self.preference.user = user
                self.onLoginSuccess()
            }.store(in: &cancelable)
    }

    func editButtonAction() {
        router.pop()
    }

    private func onLoginSuccess() {
        router.popToRoot()
    }
}
