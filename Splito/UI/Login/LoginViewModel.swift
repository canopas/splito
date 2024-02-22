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

public class LoginViewModel: ObservableObject {

    @Published var showAlert: Bool = false
    @Published private(set) var alert: AlertPrompt = .init(title: "", message: "")

    func onAppleLoginView() {

    }

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

                Auth.auth().signIn(with: credential) { authResult, error in
                    if error != nil {
                        self.alert = .init(message: "Server error")
                        self.showAlert = true
                    } else if let authResult {
                        print("XXX --- User: \(authResult.user)")
                    }
                }
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
