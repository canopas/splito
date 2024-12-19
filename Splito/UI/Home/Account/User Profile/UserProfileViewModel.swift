//
//  UserProfileViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 14/03/24.
//

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
    @Published var phoneNumber: String = ""
    @Published var userLoginType: LoginType = .Email

    @Published var profileImage: UIImage?
    @Published var profileImageUrl: String?

    @Published var sourceTypeIsCamera = false
    @Published var showImagePicker = false
    @Published var showImagePickerOption = false

    @Published var isOpenFromOnboard: Bool
    @Published var isSaveInProgress = false
    @Published var isDeleteInProgress = false

    private var currentNonce: String = ""
    private lazy var appleSignInDelegates: SignInWithAppleDelegates! = nil

    private let router: Router<AppRoute>?
    private var onDismiss: (() -> Void)?

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
            checkCameraPermission { [weak self] in
                self?.sourceTypeIsCamera = true
                self?.showImagePicker = true
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
        if let validationError = validateInputs() {
            showAlertFor(title: "Whoops!", message: validationError)
            return
        }

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

    private func validateInputs() -> String? {
        var errorMessages: [String] = []

        if firstName.trimming(spaces: .leadingAndTrailing).count < 3 {
            errorMessages.append("Your first name must be at least 3 characters long.")
        }
        if !email.isValidEmail {
            errorMessages.append("Please enter a valid email address.")
        }
        if (phoneNumber.count > 0 && phoneNumber.count < 8) || phoneNumber.count > 20 {
            errorMessages.append("Please enter a valid phone number.")
        }

        if !errorMessages.isEmpty {
            if errorMessages.count == 1 {
                return errorMessages.first ?? ""
            } else {
                return "Your profile cannot be updated. Please check the missing or incorrect information."
            }
        }
        return nil
    }

    func showDeleteAccountConfirmation() {
        alert = .init(title: "Delete your account",
                      message: "Are you ABSOLUTELY sure you want to close your splito account? You will no longer be able to log into your account or access your account history from your splito app.",
                      positiveBtnTitle: "Delete",
                      positiveBtnAction: { [weak self] in
                        Task {
                            await self?.deleteUser()
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
                alert = .init(
                    title: "", message: error.localizedDescription,
                    positiveBtnTitle: "Reauthenticate",
                    positiveBtnAction: { [weak self] in
                        self?.reAuthenticateUser()
                    }, negativeBtnTitle: "Cancel",
                    negativeBtnAction: { [weak self] in
                        self?.showAlert = false
                    }
                )
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

            user.reauthenticate(with: credential) { [weak self] _, error in
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

        case .Email:
            handleEmailLogin(completion: completion)
        }
    }

    private func handleAppleLogin(completion: @escaping (AuthCredential?) -> Void) {
        currentNonce = NonceGenerator.randomNonceString()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = NonceGenerator.sha256(currentNonce)

        appleSignInDelegates = SignInWithAppleDelegates { [weak self] (token, _, _, _) in
            guard let self else { return }
            let credential = OAuthProvider.credential(providerID: AuthProviderID.apple,
                                                      idToken: token, rawNonce: self.currentNonce)
            completion(credential)
        } onError: { [weak self] in
            self?.isDeleteInProgress = false
        }

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = appleSignInDelegates
        authorizationController.performRequests()
    }

    private func handleGoogleLogin(completion: @escaping (AuthCredential?) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            isDeleteInProgress = false
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let controller = TopViewController.shared.topViewController() else {
            isDeleteInProgress = false
            LogE("UserProfileViewModel: \(#function) Top Controller not found.")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: controller) { [weak self] result, error in
            guard error == nil else {
                self?.isDeleteInProgress = false
                LogE("UserProfileViewModel: \(#function) Google Login Error: \(String(describing: error)).")
                return
            }

            guard let user = result?.user, let idToken = user.idToken?.tokenString else {
                self?.isDeleteInProgress = false
                return
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            completion(credential)
        }
    }

    private func handleEmailLogin(completion: @escaping (AuthCredential?) -> Void) {
        let alert = UIAlertController(title: "Re-authenticate", message: "Please enter your password", preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.isDeleteInProgress = false
        })
        alert.addAction(UIAlertAction(title: "Confirm", style: .default) { [weak self] _ in
            guard let password = alert.textFields?.first?.text,
                  let email = self?.preference.user?.emailId else {
                self?.isDeleteInProgress = false
                LogE("UserProfileViewModel: \(#function) No email found for email login.")
                return
            }
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            completion(credential)
        })

        TopViewController.shared.topViewController()?.present(alert, animated: true)
    }
}
