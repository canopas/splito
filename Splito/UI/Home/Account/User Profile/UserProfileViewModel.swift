//
//  UserProfileViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 14/03/24.
//

import SwiftUI
import Data
import Combine
import BaseStyle
import AVFoundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices

public class UserProfileViewModel: BaseViewModel, ObservableObject {

    private let NAME_CHARACTER_MIN_LIMIT = 3
    private let REQUIRE_AGAIN_LOGIN_TEXT = "requires recent authentication"

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository

    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    @Published var phoneNumber: String = ""
    @Published var userLoginType: LoginType = .Phone

    @Published var profileImage: UIImage?
    @Published var profileImageUrl: String?

    @Published var sourceTypeIsCamera = false
    @Published var showImagePicker = false
    @Published var showImagePickerOption = false

    @Published var isOpenFromOnboard: Bool
    @Published var isSaveInProgress = false
    @Published var isDeleteInProgress = false
    @Published var showOTPView = false

    var verificationId = ""
    private var currentNonce: String = ""
    private lazy var appleSignInDelegates: SignInWithAppleDelegates! = nil

    private let router: Router<AppRoute>?
    private var onDismiss: (() -> Void)?

    var otpPublisher = PassthroughSubject<String, Never>()

    init(router: Router<AppRoute>?, isOpenFromOnboard: Bool, onDismiss: (() -> Void)?) {
        self.router = router
        self.onDismiss = onDismiss
        self.isOpenFromOnboard = isOpenFromOnboard
        super.init()
        fetchUserDetail()
    }

    func fetchUserDetail() {
        if let user = preference.user {
            firstName = user.firstName ?? ""
            lastName = user.lastName ?? ""
            email = user.emailId ?? ""
            phoneNumber = user.phoneNumber ?? ""
            userLoginType = user.loginType
            profileImageUrl = user.imageUrl
        }
    }

    func handleProfileTap() {
        showImagePickerOption = true
    }

    func checkCameraPermission(authorized: @escaping (() -> Void)) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        authorized()
                    }
                }
            }
            return
        case .restricted, .denied:
            showAlertFor(alert: .init(title: "Important!",
                                      message: "Camera access is required to take picture for your profile",
                                      positiveBtnTitle: "Allow", positiveBtnAction: { [weak self] in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
                self?.showAlert = false
            }))
        case .authorized:
            authorized()
        default:
            return
        }
    }

    func handleActionSelection(_ action: ActionsOfSheet) {
        switch action {
        case .camera:
            checkCameraPermission {
                self.sourceTypeIsCamera = true
                self.showImagePicker = true
            }
        case .gallery:
            sourceTypeIsCamera = false
            showImagePicker = true
        case .remove:
            profileImage = nil
            profileImageUrl = nil
        }
    }

    func updateUsersProfileData() {
        Task {
            await updateUserProfile()
        }
    }

    private func updateUserProfile() async {
        guard let user = preference.user else { return }

        var newUser = user
        newUser.firstName = firstName.trimming(spaces: .leadingAndTrailing).capitalized
        newUser.lastName = lastName.trimming(spaces: .leadingAndTrailing).capitalized
        newUser.emailId = email.trimming(spaces: .leadingAndTrailing)
        newUser.phoneNumber = phoneNumber

        let resizedImage = profileImage?.aspectFittedToHeight(200)
        let imageData = resizedImage?.jpegData(compressionQuality: 0.2)

        do {
            isSaveInProgress = true
            let user = try await userRepository.updateUserWithImage(imageData: imageData, newImageUrl: profileImageUrl, user: newUser)
            preference.user = user
            isSaveInProgress = false

            LogD("UserProfileViewModel: \(#function) User updated successfully.")
            if isOpenFromOnboard {
                onDismiss?()
            } else {
                router?.pop()
            }
        } catch {
            isSaveInProgress = false
            LogE("UserProfileViewModel: \(#function) Failed to update user: \(error).")
            showToastForError()
        }
    }

    func showDeleteAccountConfirmation() {
        alert = .init(title: "Delete your account",
                      message: "Are you ABSOLUTELY sure you want to close your splito account? You will no longer be able to log into your account or access your account history from your splito app.",
                      positiveBtnTitle: "Delete",
                      positiveBtnAction: {
                        Task {
                            await self.deleteUser()
                        }
                      },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false }, isPositiveBtnDestructive: true)
        showAlert = true
    }

    private func deleteUser() async {
        guard let user = preference.user else {
            LogD("UserProfileViewModel: \(#function) User does not exist.")
            return
        }

        do {
            isDeleteInProgress = true
            try await userRepository.deleteUser(id: user.id)
            preference.isOnboardShown = false
            preference.clearPreferenceSession()
            isDeleteInProgress = false
            goToOnboardScreen()
            LogD("UserProfileViewModel: \(#function) User deleted successfully.")
        } catch {
            isDeleteInProgress = false
            LogE("UserProfileViewModel: \(#function) Failed to delete user: \(error).")
            if error.localizedDescription.contains(REQUIRE_AGAIN_LOGIN_TEXT) {
                alert = .init(title: "", message: error.localizedDescription,
                              positiveBtnTitle: "Reauthenticate", positiveBtnAction: {
                    self.reAuthenticateUser()
                }, negativeBtnTitle: "Cancel", negativeBtnAction: {
                    self.showAlert = false
                })
                showAlert = true
            } else {
                showToastForError()
            }
        }
    }

    private func goToOnboardScreen() {
        router?.popToRoot()
    }
}

// MARK: - Reauthentication Actions
extension UserProfileViewModel {
    private func reAuthenticateUser() {
        guard let user = FirebaseProvider.auth.currentUser else {
            LogE("UserProfileViewModel: \(#function) User not found for delete.")
            return
        }

        isDeleteInProgress = true
        user.reload { [weak self] error in
            if let error {
                self?.isDeleteInProgress = false
                self?.showAlertFor(message: error.localizedDescription)
                LogE("UserProfileViewModel: \(#function) Error reloading user: \(error).")
            } else {
                self?.promptForReAuthentication(user)
            }
        }
    }

    func promptForReAuthentication(_ user: User) {
        getAuthCredential(user) { [weak self] credential in
            guard let credential else {
                self?.isDeleteInProgress = false
                LogE("UserProfileViewModel: \(#function) Credential are - \(String(describing: credential))")
                return
            }

            user.reauthenticate(with: credential) { _, error in
                guard let self else { return }
                if let error {
                    self.isDeleteInProgress = false
                    self.showAlertFor(message: error.localizedDescription)
                    LogE("UserProfileViewModel: \(#function) Error re-authenticating user: \(error).")
                } else {
                    Task {
                        await self.deleteUser()
                    }
                }
            }
        }
    }

    private func getAuthCredential(_ authUser: User, completion: @escaping (AuthCredential?) -> Void) {
        guard let appUser = preference.user else {
            isDeleteInProgress = false
            return
        }

        switch appUser.loginType {
        case .Apple:
            handleAppleLogin(completion: completion)

        case .Google:
            handleGoogleLogin(completion: completion)

        case .Phone:
            handlePhoneLogin(completion: completion)
        }
    }

    private func handleAppleLogin(completion: @escaping (AuthCredential?) -> Void) {
        currentNonce = NonceGenerator.randomNonceString()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = NonceGenerator.sha256(currentNonce)

        isDeleteInProgress = false

        appleSignInDelegates = SignInWithAppleDelegates { (token, _, _, _) in
            self.isDeleteInProgress = true
            let credential = OAuthProvider.credential(providerID: AuthProviderID(rawValue: "apple.com")!, idToken: token, rawNonce: self.currentNonce)
            completion(credential)
        }

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = appleSignInDelegates
        authorizationController.performRequests()
    }

    private func handleGoogleLogin(completion: @escaping (AuthCredential?) -> Void) {
        let clientID = FirebaseApp.app()?.options.clientID ?? ""

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let controller = TopViewController.shared.topViewController() else {
            isDeleteInProgress = false
            LogE("UserProfileViewModel: \(#function) Top Controller not found.")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: controller) { result, error in
            guard error == nil else {
                self.isDeleteInProgress = false
                LogE("UserProfileViewModel: \(#function) Google Login Error: \(String(describing: error)).")
                return
            }

            guard let user = result?.user, let idToken = user.idToken?.tokenString else { return }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            completion(credential)
        }
    }

    private func handlePhoneLogin(completion: @escaping (AuthCredential?) -> Void) {
        guard let phoneNumber = preference.user?.phoneNumber else {
            self.isDeleteInProgress = false
            LogE("UserProfileViewModel: \(#function) No phone number found for phone login.")
            return
        }

        FirebaseProvider.phoneAuthProvider
            .verifyPhoneNumber(phoneNumber, uiDelegate: nil) { [weak self] verificationID, error in
                guard let self = self else { return }
                self.isDeleteInProgress = false
                if let error {
                    self.handleFirebaseAuthErrors(error)
                } else {
                    self.phoneNumber = phoneNumber
                    self.verificationId = verificationID ?? ""
                    self.showOTPView = true

                    self.otpPublisher
                        .sink { otp in
                            guard !otp.isEmpty else { return }
                            self.showOTPView = false

                            let credential = FirebaseProvider.phoneAuthProvider
                                .credential(withVerificationID: self.verificationId, verificationCode: otp)
                            completion(credential)
                        }
                        .store(in: &self.cancelable)
                }
            }
    }

    private func handleFirebaseAuthErrors(_ error: Error) {
        if (error as NSError).code == FirebaseAuth.AuthErrorCode.webContextCancelled.rawValue {
            showAlertFor(message: "Something went wrong! Please try after some time.")
        } else if (error as NSError).code == FirebaseAuth.AuthErrorCode.tooManyRequests.rawValue {
            showAlertFor(message: "Too many attempts, please try after some time.")
        } else if (error as NSError).code == FirebaseAuth.AuthErrorCode.missingPhoneNumber.rawValue {
            showAlertFor(message: "Enter a valid phone number.")
        } else if (error as NSError).code == FirebaseAuth.AuthErrorCode.invalidPhoneNumber.rawValue {
            showAlertFor(message: "Enter a valid phone number.")
        } else {
            LogE("UserProfileViewModel: \(#function) Phone login fail with error: \(error).")
            showAlertFor(title: "Authentication failed", message: "Apologies, we were not able to complete the authentication process. Please try again later.")
        }
    }
}
