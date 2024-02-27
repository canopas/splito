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
    @Published private(set) var currentState: ViewState = .initial
    
    @Inject var firestore: FirestoreManager
    @Inject var preference: SplitoPreference
    
    var resendTimer: Timer?
    var phoneNumber: String
    var verificationId: String
    var cancellable = Set<AnyCancellable>()
    
    private let router: Router<AppRoute>
    
    init(router: Router<AppRoute>, phoneNumber: String, verificationId: String) {
        self.router = router
        self.phoneNumber = phoneNumber
        self.verificationId = verificationId
        
        super.init()
        
        runTimer()
    }
    
    func verifyOTP() {
        guard !otp.isEmpty else {
            return
        }
        
        let credential = FirebaseProvider.phoneAuthProvider.credential(withVerificationID: verificationId, verificationCode: otp)
        showLoader = true
        FirebaseProvider.auth.signIn(with: credential) {[weak self] (result, _) in
            self?.showLoader = false
            if let result {
                self?.resendTimer?.invalidate()
                self?.currentState = .initial
                let user = AppUser(id: result.user.uid, firstName: nil, lastName: nil, emailId: nil, phoneNumber: result.user.phoneNumber, loginType: .Phone)
                self?.storeUser(user: user)
            } else {
                self?.currentState = .initial
                self?.onLoginError()
            }
        }
    }
    
    private func phoneLogin(authIdToken: String) {
        router.updateRoot(root: .Home)
    }
    
    func resendOtp() {
        currentState = .loading
        FirebaseProvider.phoneAuthProvider.verifyPhoneNumber((phoneNumber), uiDelegate: nil) { [weak self] (verificationID, error) in
            if error != nil {
                if (error! as NSError).code == FirebaseAuth.AuthErrorCode.webContextCancelled.rawValue {
                    self?.showAlertFor(message: "Something went wrong! Please try after some time.")
                } else if (error! as NSError).code == FirebaseAuth.AuthErrorCode.tooManyRequests.rawValue {
                    self?.showAlertFor(title: "Warning !!!", message: "Too many attempts, please try after some time")
                } else if (error! as NSError).code == FirebaseAuth.AuthErrorCode.missingPhoneNumber.rawValue || (error! as NSError).code == FirebaseAuth.AuthErrorCode.invalidPhoneNumber.rawValue {
                    self?.showAlertFor(message: "Enter a valid phone number")
                } else {
                    LogE("Firebase: Phone login fail with error: \(error.debugDescription)")
                    self?.showAlertFor(title: "Authentication failed", message: "Apologies, we were not able to complete the authentication process. Please try again later.")
                }
                self?.currentState = .initial
            } else {
                self?.currentState = .initial
                self?.verificationId = verificationID ?? ""
                self?.runTimer()
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
    
    func onLoginError() {
        showAlertFor(title: "Invalid OTP", message: "Please, enter a valid OTP code.")
    }
    
    func showFailAlert() {
        showAlertFor(alert: .init(title: "Authentication failed", message: "Apologies, we were not able to complete the authentication process. Please try again later.", positiveBtnAction: { [weak self] in
            self?.router.pop()
        }))
    }
    
    private func storeUser(user: AppUser) {
        firestore.fetchUsers()
            .sink { _ in
            } receiveValue: { [weak self] users in
                guard let self = self else { return }
                let searchedUser = users.first(where: { $0.id == user.id })
                
                if let searchedUser {
                    self.preference.user = searchedUser
                    self.goToHome()
                } else {
                    self.firestore.addUser(user: user)
                        .receive(on: DispatchQueue.main)
                        .sink { completion in
                            switch completion {
                            case .failure(let error):
                                self.alert = .init(message: error.localizedDescription)
                                self.showAlert = true
                            case .finished:
                                self.preference.user = user
                                self.preference.isVerifiedUser = true
                            }
                        } receiveValue: { [weak self] _ in
                            self?.goToHome()
                        }
                        .store(in: &self.cancellable)
                }
            }
            .store(in: &cancellable)
    }
    
    func editButtonAction() {
        router.pop()
    }
    
    private func goToHome() {
        router.popToRoot()
        router.updateRoot(root: .Home)
    }
}

// MARK: - View's State & Alert
extension VerifyOtpViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
