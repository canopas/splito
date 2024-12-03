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

    @Published var isPasswordVisible = false
    @Published private(set) var showLoader = false
    @Published var email = ""
    @Published var password = ""

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
    }

    func onEmailSignUp() {
        FirebaseAuth.Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            if let error {
                LogE("EmailLoginViewModel: Error during sign up: \(error)")
                self.alert = .init(message: "Sign-up failed: \(error)")
                self.showAlert = true
            } else if let authResult {
                let user = AppUser(id: authResult.user.uid, firstName: "", lastName: "",
                                   emailId: email, phoneNumber: nil, loginType: .Email)
                Task {
                    await self.storeUser(user: user)
                }
            }
        }
    }

    func onEmailLoginClick() {
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            guard let self = self else { return }
            if let error {
                LogE("EmailLoginViewModel: Error during login: \(error)")
                self.alert = .init(message: "Login failed: \(error)")
                self.showAlert = true
            } else {
                LogD("EmailLoginViewModel: User logged in successfully.")
                self.onLoginSuccess()
            }
        }
    }

    private func storeUser(user: AppUser) async {
        do {
            let user = try await userRepository.storeUser(user: user)
            self.preference.isVerifiedUser = true
            self.preference.user = user
            self.onLoginSuccess()
            LogD("EmailLoginViewModel: \(#function) User stored successfully.")
        } catch {
            LogE("EmailLoginViewModel: \(#function) Failed to store user: \(error).")
            self.alert = .init(message: error.localizedDescription)
            self.showAlert = true
        }
    }

    private func onLoginSuccess() {
        //        if onLoginSuccess == nil {
        //            router?.popToRoot()
        //        } else {
        //            onLoginSuccess?(otp)
        //        }
    }

    func handleBackBtnTap() {
        router.pop()
    }

    func handlePasswordEyeTap() {
        isPasswordVisible.toggle()  // Toggle password visibility
    }

    func onEditingChanged(abc: Bool) {

    }
}

extension EmailLoginViewModel {
    enum EmailLoginField: Hashable {
        case email
        case password
    }
}
