//
//  LoginViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 20/02/24.
//

import Data
import GoogleSignIn
import FirebaseCore
import FirebaseAuth
import AuthenticationServices
import BaseStyle

public class LoginViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository

    @Published private(set) var showGoogleLoading = false
    @Published private(set) var showAppleLoading = false

    private var currentNonce: String = ""
    private var appleSignInDelegates: SignInWithAppleDelegates?
    private let router: Router<AppRoute>
    private var onDismiss: (() -> Void)?

    init(router: Router<AppRoute>, onDismiss: (() -> Void)? = nil) {
        self.router = router
        self.onDismiss = onDismiss
    }

    // MARK: - Data Loading
    func onGoogleLoginClick() {
        showGoogleLoading = true

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            showGoogleLoading = false
            return
        }

        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let controller = TopViewController.shared.topViewController() else {
            showGoogleLoading = false
            LogE("LoginViewModel: \(#function) Top Controller not found.")
            return
        }

        Task {
            await handleGoogleLoginAction(controller: controller)
        }
    }

    private func handleGoogleLoginAction(controller: UIViewController) async {
        do {
            let authUser = try await GIDSignIn.sharedInstance.signIn(withPresenting: controller).user
            guard let idToken = authUser.idToken?.tokenString else {
                showGoogleLoading = false
                return
            }

            let firstName = authUser.profile?.givenName ?? ""
            let lastName = authUser.profile?.familyName ?? ""
            let email = authUser.profile?.email ?? ""

            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: authUser.accessToken.tokenString)
            await self.performFirebaseLogin(credential: credential, loginType: .Google, userData: (firstName, lastName, email))
        } catch {
            showGoogleLoading = false
            LogE("LoginViewModel: \(#function) Google Login Error: \(String(describing: error)).")
        }
    }

    func onAppleLoginClick() {
        self.showAppleLoading = true
        self.currentNonce = NonceGenerator.randomNonceString()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = NonceGenerator.sha256(currentNonce)

        appleSignInDelegates = SignInWithAppleDelegates { [weak self] (token, fName, lName, email)  in
            guard let self else { return }
            let credential = OAuthProvider.credential(providerID: AuthProviderID.apple,
                                                      idToken: token, rawNonce: self.currentNonce)
            Task {
                await self.performFirebaseLogin(credential: credential, loginType: .Apple, userData: (fName, lName, email))
            }
        } onError: {
            self.showAppleLoading = false
        }

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = appleSignInDelegates
        authorizationController.performRequests()
    }

    private func performFirebaseLogin(credential: AuthCredential, loginType: LoginType, userData: (String, String, String)) async {
        do {
            showAppleLoading = loginType == .Apple
            showGoogleLoading = loginType == .Google

            let authUser = try await FirebaseProvider.auth.signIn(with: credential).user
            let user = AppUser(id: authUser.uid, firstName: userData.0, lastName: userData.1,
                               emailId: userData.2, phoneNumber: nil, loginType: loginType)
            await self.storeUser(user: user)
        } catch {
            showAppleLoading = false
            showGoogleLoading = false
            handleFirebaseAuthErrors(error, loginType: loginType)
            LogE("LoginViewModel: \(#function) Failed to perform Firebase login with \(loginType): \(error.localizedDescription).")
        }
    }

    private func storeUser(user: AppUser) async {
        do {
            let user = try await userRepository.storeUser(user: user)
            manageLoginSuccess(user: user)
            LogD("LoginViewModel: \(#function) User stored successfully.")
        } catch {
            showAppleLoading = false
            showGoogleLoading = false
            LogE("LoginViewModel: \(#function) Failed to store user: \(error).")
            alert = .init(message: "Something went wrong! Please try after some time.")
            showAlert = true
        }
    }

    private func manageLoginSuccess(user: AppUser) {
        preference.user = user
        preference.isVerifiedUser = true
        showAppleLoading = false
        showGoogleLoading = false
        onDismiss?()
    }

    // MARK: - User Actions
    func onEmailLoginClick() {
        router.push(.EmailLoginView(onDismiss: onDismiss))
    }

    // MARK: - Error handling
    private func handleFirebaseAuthErrors(_ error: Error, loginType: LoginType) {
        guard let authErrorCode = FirebaseAuth.AuthErrorCode(rawValue: (error as NSError).code) else {
            showAlertFor(title: "Error", message: "Something went wrong! Please try after some time.")
            return
        }

        switch authErrorCode {
        case .networkError:
            showAlertFor(title: "Network Error", message: "No internet connection!")
        case .invalidCredential:
            showAlertFor(title: "Credential Error", message: "Invalid credentials. Please try again.")
        case .userDisabled:
            showAlertFor(title: "Account Disabled", message: "This account has been disabled. Please contact support.")
        case .tooManyRequests:
            showAlertFor(title: "Error", message: "Too many attempts, please try again later.")
        case .credentialAlreadyInUse:
            showAlertFor(title: "Credential In Use", message: "This credential is already associated with another account. Please use a different method to log in.")
        case .accountExistsWithDifferentCredential:
            showAlertFor(title: "Error", message: "This email is already associated with a different sign-in method. Please use that method to log in.")
        case .requiresRecentLogin:
            showAlertFor(title: "Re-authentication Required", message: "Please log in again to perform this action.")
        case .webContextCancelled:
            showAlertFor(title: "Cancelled", message: "The login process was cancelled.")
        case .invalidUserToken:
            showAlertFor(title: "Invalid Session", message: "Your session has expired. Please log in again.")
        case .sessionExpired:
            showAlertFor(title: "Session Expired", message: "Your session has expired. Please try again.")
        case .webNetworkRequestFailed:
            showAlertFor(title: "Network Error", message: "There was an issue with the network request. Please try again.")
        default:
            showAlertFor(title: "Authentication failed", message: "We couldn't complete the authentication process. Please try again later.")
        }

        LogE("LoginViewModel: \(#function) \(loginType) Login fail with error: \(error).")
    }
}

// MARK: - View's State & Alert
extension LoginViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
