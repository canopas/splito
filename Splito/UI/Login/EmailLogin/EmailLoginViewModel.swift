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
    private func validateEmailAndPassword() -> Bool {
        email = email.trimmingCharacters(in: .whitespacesAndNewlines)
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

    func onCreateAccountClick() {
        guard validateEmailAndPassword() else { return }
        Task {
            isSignupInProgress = true
            await handleFirebaseLogin(email: email, password: password, isForLogin: false)
        }
    }

    func onLoginClick() {
        guard validateEmailAndPassword() else { return }
        Task {
            isLoginInProgress = true
            await handleFirebaseLogin(email: email, password: password, isForLogin: true)
        }
    }

    private func handleFirebaseLogin(email: String, password: String, isForLogin: Bool) async {
        do {
            let authUser: User
            if isForLogin {
                authUser = try await FirebaseProvider.auth.signIn(withEmail: email, password: password).user
            } else {
                authUser = try await FirebaseProvider.auth.createUser(withEmail: email, password: password).user
            }

            let user = AppUser(id: authUser.uid, firstName: "", lastName: "", emailId: email, loginType: .Email)
            await storeUser(user: user)
        } catch {
            hideProgressLoaders()
            handleFirebaseAuthErrors(error)
            LogE("EmailLoginViewModel: \(#function) Error during \(isForLogin ? "login" : "sign up"): \(error).")
        }
    }

    private func storeUser(user: AppUser) async {
        do {
            let user = try await userRepository.storeUser(user: user)
            preference.user = user
            handleLoginSuccessState()
        } catch {
            LogE("EmailLoginViewModel: \(#function) Failed to store user: \(error).")
            hideProgressLoaders()
            alert = .init(message: "Something went wrong! Please try after some time.")
            showAlert = true
        }
    }

    private func hideProgressLoaders() {
        isLoginInProgress = false
        isSignupInProgress = false
    }

    private func handleLoginSuccessState() {
        preference.isVerifiedUser = true
        hideProgressLoaders()
        dismissLoginFlow()
    }

    private func dismissLoginFlow() {
        if onDismiss != nil {
            onDismiss?()
        } else {
            router.popToRoot()
        }
    }

    func onForgotPasswordClick() {
        email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.isValidEmail else {
            showAlertFor(title: "Whoops!", message: "Please enter a valid email address.")
            return
        }

        Task {
            do {
                if let user = try await userRepository.fetchUserBy(email: email) {
                    if user.loginType != .Email {
                        showAlertFor(title: "Email Already in Use", message: "The email address is already associated with an existing account. Please use a different email or log in to your existing account.")
                        return
                    }
                }
                try await FirebaseProvider.auth.sendPasswordReset(withEmail: email)
                self.showAlertFor(title: "Email sent", message: "An email has been sent to \(email) with instructions to reset your password.")
            } catch {
                LogE("EmailLoginViewModel: \(#function) Failed to send password reset email: \(error)")
                handleFirebaseAuthErrors(error, isPasswordReset: true)
            }
        }
    }

    // MARK: - Error handling
    private func handleFirebaseAuthErrors(_ error: Error, isPasswordReset: Bool = false) {
        guard let authErrorCode = FirebaseAuth.AuthErrorCode(rawValue: (error as NSError).code) else {
            showAlertFor(title: "Error", message: "Something went wrong! Please try after some time.")
            return
        }

        switch authErrorCode {
        case .networkError:
            showAlertFor(title: "Network Error", message: "No internet connection!")
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
