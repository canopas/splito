//
//  EmailLoginViewModel.swift
//  Splito
//
//  Created by Nirali Sonani on 03/12/24.
//

import Data
import Foundation
import FirebaseAuth

public class EmailLoginViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository

    @Published private(set) var isLoginInProgress = false
    @Published private(set) var isSignupInProgress = false

    @Published var email = ""
    @Published var password = ""

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
    }

    // MARK: - User Actions
    func onCreateAccountClick() {
        guard validateEmailAndPassword() else { return }

        isSignupInProgress = true
        FirebaseAuth.Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self else { return }
            isSignupInProgress = false
            self.handleAuthResponse(result: result, error: error, isLogin: false)
        }
    }

    func onEmailLoginClick() {
        guard validateEmailAndPassword() else { return }

        isLoginInProgress = true
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self else { return }
            isLoginInProgress = false
            self.handleAuthResponse(result: result, error: error, isLogin: true)
        }
    }

    private func handleAuthResponse(result: AuthDataResult?, error: Error?, isLogin: Bool) {
        if let error {
            LogE("EmailLoginViewModel: \(#function) Error during \(isLogin ? "login" : "sign up"): \(error)")
            handleFirebaseAuthErrors(error)
        } else if let result {
            let user = AppUser(id: result.user.uid, firstName: "", lastName: "",
                               emailId: email, phoneNumber: nil, loginType: .Email)
            Task { await storeUser(user: user) }
            LogD("EmailLoginViewModel: \(#function) User \(isLogin ? "logged in" : "signed up") successfully.")
        } else {
            self.alert = .init(message: "Contact Support")
            self.showAlert = true
        }
    }

    private func validateEmailAndPassword() -> Bool {
        if !email.isValidEmail {
            showAlertFor(title: "Error", message: "Please enter a valid email address.")
            return false
        }
        if password.count < 4 {
            showAlertFor(title: "Error", message: "Password must be at least 4 characters long.")
            return false
        }

        return true
    }

    private func storeUser(user: AppUser) async {
        do {
            let user = try await userRepository.storeUser(user: user)
            self.preference.isVerifiedUser = true
            self.preference.user = user
            self.router.popToRoot()
            LogD("EmailLoginViewModel: \(#function) User stored successfully.")
        } catch {
            LogE("EmailLoginViewModel: \(#function) Failed to store user: \(error).")
            self.alert = .init(message: error.localizedDescription)
            self.showAlert = true
        }
    }

    func onForgotPasswordClick() {

    }

    func handleBackBtnTap() {
        router.pop()
    }

    // MARK: - Error handling 
    private func handleFirebaseAuthErrors(_ error: Error) {
        let errorCode = (error as NSError).code

        switch FirebaseAuth.AuthErrorCode(rawValue: errorCode) {
        case .webContextCancelled:
            showAlertFor(message: "Something went wrong! Please try after some time.")
        case .tooManyRequests:
            showAlertFor(message: "Too many attempts, please try after some time.")
        case .invalidEmail:
            showAlertFor(title: "Invalid Email", message: "The email address is not valid. Please check and try again.")
        case .wrongPassword:
            showAlertFor(title: "Incorrect Password", message: "The password you entered is incorrect. Please try again.")
        case .userNotFound:
            showAlertFor(title: "Account Not Found", message: "No account found with the provided email address. Please sign up.")
        case .userDisabled:
            showAlertFor(title: "Account Disabled", message: "This account has been disabled. Please contact support.")
        case .invalidCredential:
            showAlertFor(title: "Incorrect email or password", message: "The email or password you entered is incorrect. Please try again.")
        default:
            LogE("EmailLoginViewModel: \(#function) Phone login fail with error: \(error).")
            showAlertFor(title: "Authentication failed", message: "Apologies, we were not able to complete the authentication process. Please try again later.")
        }
    }
}

extension EmailLoginViewModel {
    enum EmailLoginField: Hashable {
        case email
        case password
    }
}
