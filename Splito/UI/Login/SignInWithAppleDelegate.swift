//
//  SignInWithAppleDelegate.swift
//  Splito
//
//  Created by Amisha Italiya on 22/02/24.
//

import Data
import AuthenticationServices

class SignInWithAppleDelegates: NSObject {

    private let signInSucceeded: (String, String, String) -> Void

    init(signInSucceeded: @escaping (String, String, String) -> Void) {
        self.signInSucceeded = signInSucceeded
    }
}

extension SignInWithAppleDelegates: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {

            guard let appleIDToken = appleIDCredential.identityToken else {
                LogE("SignInWithAppleDelegates: Unable to fetch identity token.")
                return
            }

            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                LogE("SignInWithAppleDelegates: Unable to serialize token string from data: \(appleIDToken.debugDescription).")
                return
            }

            let firstName = appleIDCredential.fullName?.givenName ?? ""
            let lastName = appleIDCredential.fullName?.familyName ?? ""

            self.signInSucceeded(idTokenString, firstName, lastName)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        LogE("SignInWithAppleDelegates: Apple login complete with error:: \(error)")
    }
}
