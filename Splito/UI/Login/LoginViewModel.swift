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

    @Inject private var mainRouter: Router<MainRoute>
    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository

    private var currentNonce: String = ""

    var appleSignInDelegates: SignInWithAppleDelegates! = nil

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
    }

    func onGoogleLoginClick() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }

        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let controller = TopViewController.shared.topViewController() else {
            LogE("LoginViewModel :: Top Controller not found.")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: controller) { [unowned self] result, error in
            guard error == nil else {
                LogE("LoginViewModel :: Google Login Error: \(String(describing: error))")
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

    func onAppleLoginClick() {
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
                    print("LoginViewModel :: Firebase Error: \(error), with type Apple login.")
                    self.alert = .init(message: "Server error")
                    self.showAlert = true
                } else if let result {
                    self.currentState = .initial
                    let user = AppUser(id: result.user.uid, firstName: userData.0, lastName: userData.1, emailId: userData.2, phoneNumber: nil, loginType: loginType)
                    self.storeUser(user: user)
                    print("LoginViewModel :: Logged in User: \(result.user)")
                } else {
                    self.alert = .init(message: "Contact Support")
                    self.showAlert = true
                }
            }
    }

    private func storeUser(user: AppUser) {
        userRepository.storeUser(user: user)
            .sink { [weak self] completion in
                guard let self else { return }
                switch completion {
                case .failure(let error):
                    self.alert = .init(message: error.localizedDescription)
                    self.showAlert = true
                case .finished:
                    self.preference.user = user
                    self.preference.isVerifiedUser = true
                }
            } receiveValue: { [weak self] _ in
                guard let self else { return }
                self.onLoginSuccess()
            }.store(in: &cancelable)
    }

    private func onLoginSuccess() {
        mainRouter.updateRoot(root: .HomeView)
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
