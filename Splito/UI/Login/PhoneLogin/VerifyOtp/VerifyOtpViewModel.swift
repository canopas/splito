//
//  VerifyOtpViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 23/02/24.
//

import Data
import SwiftUI
import FirebaseAuth

public class VerifyOtpViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var userRepository: UserRepository

    @Published var otp = ""
    @Published var resendOtpCount: Int = 30
    @Published private(set) var showLoader: Bool = false
    @Published private(set) var resendTimer: Timer?

    var hiddenPhoneNumber: String {
        let count = phoneNumber.count
        guard count > 4 else { return phoneNumber }
        let middleNumbers = String(repeating: "*", count: count - 4)
        return "\(phoneNumber.prefix(2))\(middleNumbers)\(phoneNumber.suffix(2))"
    }

    private let router: Router<AppRoute>?
    private let dialCode: String
    private var phoneNumber: String
    private var verificationId: String
    private var isFromPhoneLogin = false

    private var onLoginSuccess: ((String) -> Void)?

    init(router: Router<AppRoute>? = nil, phoneNumber: String, dialCode: String = "",
         verificationId: String, onLoginSuccess: ((String) -> Void)? = nil) {
        self.router = router
        self.phoneNumber = phoneNumber
        self.dialCode = dialCode
        self.verificationId = verificationId
        self.onLoginSuccess = onLoginSuccess
        super.init()
        runTimer()
        isFromPhoneLogin = onLoginSuccess == nil
    }

    // MARK: - Data Loading
    func verifyOTP() {
        guard !otp.isEmpty else { return }

        let credential = FirebaseProvider.phoneAuthProvider.credential(withVerificationID: verificationId,
                                                                       verificationCode: otp)
        showLoader = true
        FirebaseProvider.auth.signIn(with: credential) {[weak self] (result, _) in
            self?.showLoader = false
            if let result {
                guard let self else { return }
                self.resendTimer?.invalidate()
                let user = AppUser(id: result.user.uid, firstName: nil, lastName: nil, emailId: nil,
                                   phoneNumber: result.user.phoneNumber, loginType: .Phone)
                Task {
                    await self.storeUser(user: user)
                }
            } else {
                self?.onLoginError()
            }
        }
    }

    func resendOtp() {
        showLoader = true
        FirebaseProvider.phoneAuthProvider.verifyPhoneNumber((dialCode + phoneNumber), uiDelegate: nil) { [weak self] (verificationID, error) in
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
                    self.showAlertFor(title: "Authentication failed",
                                      message: "Apologies, we were not able to complete the authentication process. Please try again later.")
                }
            } else {
                self.verificationId = verificationID ?? ""
                self.runTimer()
            }
        }
    }

    // MARK: - User Actions
    func handleBackBtnTap() {
        router?.pop()
    }

    func editButtonAction() {
        router?.pop()
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

    private func storeUser(user: AppUser) async {
        do {
            let user = try await userRepository.storeUser(user: user)
            self.preference.isVerifiedUser = true
            self.preference.user = user
            self.onVerificationSuccess()
        } catch {
            self.alert = .init(message: error.localizedDescription)
            self.showAlert = true
        }
    }

    private func onVerificationSuccess() {
        if onLoginSuccess == nil {
            router?.popToRoot()
        } else {
            onLoginSuccess?(otp)
        }
    }
}
