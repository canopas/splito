//
//  LoginViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 20/02/24.
//

import Data
import BaseStyle
import GoogleSignIn
import FirebaseCore
import FirebaseAuth
import AuthenticationServices

public class LoginViewModel: ObservableObject {

    @Published var showAlert: Bool = false
    @Published private(set) var alert: AlertPrompt = .init(title: "", message: "")
    @Published private(set) var currentState: ViewState = .initial

    private var currentNonce: String = ""

    var appleSignInDelegates: SignInWithAppleDelegates! = nil

    func onGoogleLoginClick() {
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            LogE("LoginViewModel: Alreday signed in.")
//            GIDSignIn.sharedInstance.restorePreviousSignIn { _, _ in }
        } else {
            guard let clientID = FirebaseApp.app()?.options.clientID else { return }

            // Create Google Sign In configuration object.
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config

            guard let controller = TopViewController.shared.topViewController() else {
                LogE("LoginViewModel: Top Controller not found.")
                return
            }

            GIDSignIn.sharedInstance.signIn(withPresenting: controller) { [unowned self] result, error in
                guard error == nil else {
                    LogE("LoginViewModel: Google Login Error: \(String(describing: error))")
                    return
                }
                guard let user = result?.user, let idToken = user.idToken?.tokenString else { return }

                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
                self.performFirebaseLogin(credential: credential)
            }
        }
    }

    func onAppleLoginView() {
        self.currentNonce = NonceGenerator.randomNonceString()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = NonceGenerator.sha256(currentNonce)

        appleSignInDelegates = SignInWithAppleDelegates { (token, _, _) in
            let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: token, rawNonce: self.currentNonce)
            self.performFirebaseLogin(credential: credential)
        }

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = appleSignInDelegates
        authorizationController.performRequests()
    }

    private func performFirebaseLogin(credential: AuthCredential) {
        currentState = .loading
        FirebaseProvider.auth
            .signIn(with: credential) { [weak self] result, error in
                guard let self = self else { return }
                if let error {
                    self.currentState = .initial
                    print("LoginViewModel: Firebase Error: \(error), with type Apple login.")
                    self.alert = .init(message: "Server error")
                    self.showAlert = true
                } else if let result {
                    self.currentState = .initial
                    print("LoginViewModel: Logged in User: \(result.user)")
                } else {
                    self.alert = .init(message: "Contact Support")
                    self.showAlert = true
                }
            }
    }

    func onPhoneLoginClick() {

    }
}

// MARK: - View's State & Alert
extension LoginViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
