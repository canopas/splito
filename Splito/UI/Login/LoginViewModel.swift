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
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }

        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let controller = TopViewController.shared.topViewController() else {
            LogE("LoginViewModel: \(#function) Top Controller not found.")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: controller) { [unowned self] result, error in
            guard error == nil else {
                LogE("LoginViewModel: \(#function) Google Login Error: \(String(describing: error)).")
                return
            }

            guard let user = result?.user, let idToken = user.idToken?.tokenString else { return }

            let firstName = user.profile?.givenName ?? ""
            let lastName = user.profile?.familyName ?? ""
            let email = user.profile?.email ?? ""

            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            self.showGoogleLoading = true
            self.performFirebaseLogin(showGoogleLoading: showGoogleLoading, credential: credential,
                                      loginType: .Google, userData: (firstName, lastName, email))
        }
    }

    func onAppleLoginClick() {
        self.currentNonce = NonceGenerator.randomNonceString()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = NonceGenerator.sha256(currentNonce)

        appleSignInDelegates = SignInWithAppleDelegates { (token, fName, lName, email)  in
            let credential = OAuthProvider.credential(providerID: AuthProviderID.apple,
                                                      idToken: token, rawNonce: self.currentNonce)
            self.showAppleLoading = true
            self.performFirebaseLogin(showAppleLoading: self.showAppleLoading, credential: credential,
                                      loginType: .Apple, userData: (fName, lName, email))
        }

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = appleSignInDelegates
        authorizationController.performRequests()
    }

    private func performFirebaseLogin(showGoogleLoading: Bool = false, showAppleLoading: Bool = false,
                                      credential: AuthCredential, loginType: LoginType, userData: (String, String, String)) {
        self.showGoogleLoading = showGoogleLoading
        self.showAppleLoading = showAppleLoading

        FirebaseProvider.auth
            .signIn(with: credential) { [weak self] result, error in
                guard let self = self else { return }
                if let error {
                    self.showGoogleLoading = false
                    self.showAppleLoading = false
                    LogE("LoginViewModel: \(#function) Firebase Error: \(error), with type Apple login.")
                    self.alert = .init(message: "Server error")
                    self.showAlert = true
                } else if let result {
                    self.showGoogleLoading = false
                    self.showAppleLoading = false
                    let user = AppUser(id: result.user.uid, firstName: userData.0, lastName: userData.1,
                                       emailId: userData.2, phoneNumber: nil, loginType: loginType)
                    Task {
                        await self.storeUser(user: user)
                    }
                    LogD("LoginViewModel: \(#function) Logged in User: \(result.user)")
                } else {
                    self.alert = .init(message: "Contact Support")
                    self.showAlert = true
                }
            }
    }

    private func storeUser(user: AppUser) async {
        do {
            let user = try await userRepository.storeUser(user: user)
            self.preference.user = user
            self.onLoginSuccess()
            LogD("LoginViewModel: \(#function) User stored successfully.")
        } catch {
            LogE("LoginViewModel: \(#function) Failed to store user: \(error).")
            self.alert = .init(message: "Something went wrong! Please try after some time.")
            self.showAlert = true
        }
    }

    private func onLoginSuccess() {
        preference.isVerifiedUser = true
        onDismiss?()
    }

    // MARK: - User Actions
    func onEmailLoginClick() {
        router.push(.EmailLoginView(onDismiss: onDismiss))
    }
}

// MARK: - View's State & Alert
extension LoginViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
