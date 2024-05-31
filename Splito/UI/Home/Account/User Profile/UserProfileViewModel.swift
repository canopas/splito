//
//  UserProfileViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 14/03/24.
//

import SwiftUI
import Data
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
    @Published var phone: String = ""
    @Published var userLoginType: LoginType = .Phone

    @Published var profileImage: UIImage?
    @Published var profileImageUrl: String?

    @Published var sourceTypeIsCamera = false
    @Published var showImagePicker = false
    @Published var showImagePickerOption = false

    @Published var isOpenFromOnboard: Bool
    @Published var isSaveInProgress = false
    @Published var isDeleteInProgress = false

    private var currentNonce: String = ""
    private var appleSignInDelegates: SignInWithAppleDelegates! = nil

    private let router: Router<AppRoute>?
    private var onDismiss: (() -> Void)?

    init(router: Router<AppRoute>?, isOpenedFromOnboard: Bool, onDismiss: (() -> Void)?) {
        self.router = router
        self.onDismiss = onDismiss
        self.isOpenFromOnboard = isOpenedFromOnboard
        super.init()
        fetchUserDetail()
    }

    func fetchUserDetail() {
        if let user = preference.user {
            firstName = user.firstName ?? ""
            lastName = user.lastName ?? ""
            email = user.emailId ?? ""
            phone = user.phoneNumber ?? ""
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
                if granted {
                    authorized()
                }
            }
            return
        case .restricted, .denied:
            showAlertFor(alert: .init(title: "Important!",
                                      message: "Camera access is required to take picture for your profile",
                                      positiveBtnTitle: "Allow", positiveBtnAction: { [weak self] in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
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
            self.checkCameraPermission {
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

    func updateUserProfile() {
        guard let user = preference.user else { return }

        var newUser = user
        newUser.firstName = firstName.capitalized
        newUser.lastName = lastName.capitalized
        newUser.emailId = email
        newUser.phoneNumber = phone

        let resizedImage = profileImage?.aspectFittedToHeight(200)
        let imageData = resizedImage?.jpegData(compressionQuality: 0.2)

        isSaveInProgress = true
        userRepository.updateUserWithImage(imageData: imageData, newImageUrl: profileImageUrl, user: newUser)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.isSaveInProgress = false
                    self?.showAlertFor(error)
                }
            } receiveValue: { [weak self] user in
                guard let self else { return }
                self.isSaveInProgress = false
                self.preference.user = user

                if self.isOpenFromOnboard {
                    self.onDismiss?()
                } else {
                    self.router?.pop()
                }
            }.store(in: &cancelable)
    }

    func showDeleteAccountConfirmation() {
        alert = .init(title: "Delete your account",
                      message: "Are you ABSOLUTELY sure you want to close your splito account? You will no longer be able to log into your account or access your account history from your splito app.",
                      positiveBtnTitle: "Delete",
                      positiveBtnAction: { self.handleDeleteAccountAction() },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false }, isPositiveBtnDestructive: true)
        showAlert = true
    }

    func handleDeleteAccountAction() {
        guard let user = preference.user else {
            LogD("UserProfileViewModel :: user not exists.")
            return
        }

        isDeleteInProgress = true
        userRepository.deleteUser(id: user.id)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    guard let self else { return }
                    if error.descriptionText.contains(self.REQUIRE_AGAIN_LOGIN_TEXT) {
						self.alert = .init(title: "", message: error.descriptionText,
						positiveBtnTitle: "Reauthenticate", positiveBtnAction: {
							self.reAuthenticateUser()
						}, negativeBtnTitle: "Cancel", negativeBtnAction: {
							self.showAlert = false
							self.isDeleteInProgress = false
						})
                        self.showAlert = true
                    }
                }
            } receiveValue: { [weak self] _ in
                guard let self else { return }
                self.isDeleteInProgress = false
                self.preference.isOnboardShown = false
                self.preference.clearPreferenceSession()
                self.goToOnboardScreen()
				LogD("UserProfileViewModel :: user deleted.")
            }.store(in: &cancelable)
    }

	func deleteUser() {
		guard let user = preference.user else { return }
		userRepository.deleteUser(id: user.id)
			.sink { [weak self] completion in
				if case .failure(let error) = completion {
					self?.isDeleteInProgress = false
					self?.showAlertFor(error)
				}
			} receiveValue: { [weak self] _ in
				guard let self else { return }
				self.isDeleteInProgress = false
				self.preference.clearPreferenceSession()
				self.preference.isOnboardShown = false
				self.goToOnboardScreen()
				LogD("UserProfileViewModel :: user deleted.")
			}.store(in: &cancelable)
	}

    private func goToOnboardScreen() {
        router?.popToRoot()
    }
}

// MARK: - Reauthentication Actions

extension UserProfileViewModel {
    private func reAuthenticateUser() {
        guard let user = FirebaseProvider.auth.currentUser else {
            LogE("UserProfileViewModel: User not found for delete.")
            return
        }

        user.reload { [weak self] error in
            if let error {
                self?.isDeleteInProgress = false
                LogE("UserProfileViewModel: Error reloading user: \(error.localizedDescription)")
            } else {
                self?.promptForReAuthentication(user)
            }
        }
    }

    func promptForReAuthentication(_ user: User) {
        getAuthCredential(user) { [weak self] credential in
            guard let credential else {
                self?.isDeleteInProgress = false
                LogE("UserProfileViewModel: Credential are - \(String(describing: credential))")
                return
            }

            user.reauthenticate(with: credential) { _, error in
                if let error {
                    self?.isDeleteInProgress = false
                    LogE("UserProfileViewModel: Error re-authenticating user: \(error.localizedDescription)")
                } else {
                    self?.deleteUser()
                }
            }
        }
    }

    private func getAuthCredential(_ authUser: User, completion: @escaping (AuthCredential?) -> Void) {
        guard let appUser = preference.user else { return }

        switch appUser.loginType {
        case .Apple:
            currentNonce = NonceGenerator.randomNonceString()
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = NonceGenerator.sha256(currentNonce)

            isDeleteInProgress = false

            appleSignInDelegates = SignInWithAppleDelegates { (token, _, _, _)  in
                self.isDeleteInProgress = true
                let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: token, rawNonce: self.currentNonce)
                completion(credential)
            }

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = appleSignInDelegates
            authorizationController.performRequests()

        case .Google:
            let clientID = FirebaseApp.app()?.options.clientID ?? ""

            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config

            guard let controller = TopViewController.shared.topViewController() else {
                LogE("UserProfileViewModel :: Top Controller not found.")
                return
            }

            GIDSignIn.sharedInstance.signIn(withPresenting: controller) { result, error in
                guard error == nil else {
                    self.isDeleteInProgress = false
                    LogE("UserProfileViewModel :: Google Login Error: \(String(describing: error))")
                    return
                }

                guard let user = result?.user, let idToken = user.idToken?.tokenString else { return }
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
                completion(credential)
            }

        case .Phone:
            completion(nil)
        }
    }
}

// MARK: - Action sheet Struct
extension UserProfileViewModel {
    enum ActionsOfSheet {
        case camera
        case gallery
        case remove
    }
}
