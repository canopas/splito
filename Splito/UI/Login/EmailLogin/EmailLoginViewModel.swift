//
//  EmailLoginViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 03/12/24.
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
    private var onDismiss: (() -> Void)?

    init(router: Router<AppRoute>, onDismiss: (() -> Void)? = nil) {
        self.router = router
        self.onDismiss = onDismiss
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

    func onLoginClick() {
        guard validateEmailAndPassword() else { return }

        Task {
            do {
                isLoginInProgress = true

                if let user = try await userRepository.fetchUserBy(email: email) {
                    if user.loginType != .Email {
                        isLoginInProgress = false
                        showAlertFor(title: "Email Already in Use", message: "The email address is already associated with an existing account. Please use a different email or log in to your existing account.")
                        return
                    }
                } else {
                    LogE("EmailLoginViewModel: \(#function) No user found with this email.")
                }

                FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
                    self?.isLoginInProgress = false
                    self?.handleAuthResponse(result: result, error: error, isLogin: true)
                }
            } catch {
                isLoginInProgress = false
                LogE("EmailLoginViewModel: \(#function) Error fetching user: \(error).")
                showToastForError()
            }
        }
    }

    private func handleAuthResponse(result: AuthDataResult?, error: Error?, isLogin: Bool) {
        if let error {
            LogE("EmailLoginViewModel: \(#function) Error during \(isLogin ? "login" : "sign up"): \(error).")
            handleFirebaseAuthErrors(error)
        } else if let result {
            let user = AppUser(id: result.user.uid, firstName: "", lastName: "",
                               emailId: email, loginType: .Email)
            Task {
                await storeUser(user: user)
            }
            LogD("EmailLoginViewModel: \(#function) User \(isLogin ? "logged in" : "signed up") successfully.")
        } else {
            self.alert = .init(message: "Contact Support")
            self.showAlert = true
        }
    }

    private func validateEmailAndPassword() -> Bool {
        if !email.isValidEmail {
            showAlertFor(title: "Whoops!", message: "Please enter a valid email address.")
            return false
        }
        if password.count < 6 {
            showAlertFor(title: "Whoops!", message: "Password must be at least 6 characters long.")
            return false
        }

        return true
    }

    private func storeUser(user: AppUser) async {
        do {
            let user = try await userRepository.storeUser(user: user)
            preference.isVerifiedUser = true
            preference.user = user
            if onDismiss != nil {
                onDismiss?()
            } else {
                navigateToRoot()
            }
            LogD("EmailLoginViewModel: \(#function) User stored successfully.")
        } catch {
            LogE("EmailLoginViewModel: \(#function) Failed to store user: \(error).")
            alert = .init(message: "Something went wrong! Please try after some time.")
            showAlert = true
        }
    }

    func onForgotPasswordClick() {
        guard email.isValidEmail else {
            showAlertFor(title: "Whoops!", message: "Please enter a valid email address.")
            return
        }

        FirebaseAuth.Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            guard let self else { return }
            if let error {
                LogE("EmailLoginViewModel: \(#function) Failed to send password reset email: \(error)")
                self.handleFirebaseAuthErrors(error, isPasswordReset: true)
            } else {
                self.showAlertFor(title: "Email sent", message: "An email has been sent to \(email) with instructions to reset your password.")
            }
        }
    }

    func navigateToRoot() {
        router.popToRoot()
    }

    // MARK: - Error handling
    private func handleFirebaseAuthErrors(_ error: Error, isPasswordReset: Bool = false) {
        guard let authErrorCode = FirebaseAuth.AuthErrorCode(rawValue: (error as NSError).code) else {
            showAlertFor(title: "Error", message: "Something went wrong! Please try after some time.")
            return
        }

        switch authErrorCode {
        case .webContextCancelled:
            showAlertFor(title: "Error", message: "Something went wrong! Please try after some time.")
        case .tooManyRequests:
            showAlertFor(title: "Error", message: "Too many attempts, please try after some time.")
        case .invalidEmail:
            showAlertFor(title: "Invalid Email", message: "The email address is not valid. Please check and try again.")
        case .emailAlreadyInUse:
            showAlertFor(title: "Email Already in Use", message: "The email address is already associated with an existing account. Please use a different email or log in to your existing account.")
        case .userNotFound:
            showAlertFor(title: "Account Not Found", message: "No account found with the provided email address. Please sign up.")
        case .userDisabled:
            showAlertFor(title: "Account Disabled", message: "This account has been disabled. Please contact support.")
        case .invalidCredential:
            showAlertFor(title: "Incorrect email or password", message: "The email or password you entered is incorrect. Please try again.")
        case .networkError:
            showAlertFor(title: "Error", message: "No internet connection!")
        default:
            isPasswordReset ? showAlertFor(title: "Error", message: "Unable to send a password reset email. Please try again later.") : showAlertFor(title: "Authentication failed", message: "Apologies, we were not able to complete the authentication process. Please try again later.")
        }

        LogE("EmailLoginViewModel: \(#function) \((isPasswordReset) ? "Password reset" : "Email login") fail with error: \(error).")
    }
}

extension EmailLoginViewModel {
    enum EmailLoginField: Hashable {
        case email
        case password
    }
}
