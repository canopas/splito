//
//  LoginViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 20/02/24.
//

import Data
import Combine
import BaseStyle
import GoogleSignIn
import FirebaseCore
import FirebaseAuth
import AuthenticationServices

public class LoginViewModel: BaseViewModel, ObservableObject {

    @Published private(set) var currentState: ViewState = .initial

    @Inject var firestore: FirestoreManager
    @Inject var preference: SplitoPreference

    private var currentNonce: String = ""
    private var cancellable = Set<AnyCancellable>()

    private let router: Router<AppRoute>
    var appleSignInDelegates: SignInWithAppleDelegates! = nil

    init(router: Router<AppRoute>) {
        self.router = router
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

                let firstName = user.profile?.givenName ?? ""
                let lastName = user.profile?.familyName ?? ""
                let email = user.profile?.email ?? ""

                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
                self.performFirebaseLogin(credential: credential, loginType: .Google, userData: (firstName, lastName, email))
            }
        }
    }

    func onAppleLoginView() {
        self.currentNonce = NonceGenerator.randomNonceString()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = NonceGenerator.sha256(currentNonce)

        appleSignInDelegates = SignInWithAppleDelegates { (token, fName, lName, email)  in
            let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: token, rawNonce: self.currentNonce)
            self.performFirebaseLogin(credential: credential, loginType: .Apple, userData: (fName, lName, email))
        }

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = appleSignInDelegates
        authorizationController.performRequests()
    }

    private func performFirebaseLogin(credential: AuthCredential, loginType: LoginType, userData: (String, String, String)) {
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
                    let user = AppUser(id: result.user.uid, firstName: userData.0, lastName: userData.1, emailId: userData.2, phoneNumber: nil, loginType: loginType)
                    self.storeUser(user: user)
                    print("LoginViewModel: Logged in User: \(result.user)")
                } else {
                    self.alert = .init(message: "Contact Support")
                    self.showAlert = true
                }
            }
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

    private func goToHome() {
        router.updateRoot(root: .Home)
    }

    func onPhoneLoginClick() {
        router.push(.PhoneLoginView)
    }
}

// MARK: - View's State & Alert
extension LoginViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
