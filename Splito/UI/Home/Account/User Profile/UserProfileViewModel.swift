//
//  UserProfileViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 14/03/24.
//

import SwiftUI
import Data
import AVFoundation

public class UserProfileViewModel: BaseViewModel, ObservableObject {

    private let NAME_CHARACTER_MIN_LIMIT = 3

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

    @Published var isSaveInProgress: Bool = false
    @Published var isDeleteInProgress: Bool = false
    @Published var isOpenedFromOnboard: Bool

    private let router: Router<AppRoute>?
    private var onDismiss: (() -> Void)?

    init(router: Router<AppRoute>?, isOpenedFromOnboard: Bool, onDismiss: (() -> Void)?) {
        self.router = router
        self.onDismiss = onDismiss
        self.isOpenedFromOnboard = isOpenedFromOnboard
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
        if let user = preference.user {
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

                    if self.isOpenedFromOnboard {
                        self.onDismiss?()
                    } else {
                        self.router?.pop()
                    }
                }.store(in: &cancelable)
        }
    }

    func showDeleteAccountConfirmation() {
        alert = .init(title: "Delete your account", message: "Are you ABSOLUTELY sure you want to close your splito account? You will no longer be able to log into your account or access your account history from your splito app",
                      positiveBtnTitle: "Delete",
                      positiveBtnAction: { self.handleDeleteAction() },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false }, isPositiveBtnDestructive: true)
        showAlert = true
    }

    func handleDeleteAction() {
        if let user = preference.user {
            isDeleteInProgress = true
            userRepository.deleteUser(id: user.id)
                .sink { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.isDeleteInProgress = false
                        self?.showAlertFor(error)
                    }
                } receiveValue: { [weak self] _ in
                    guard let self else { return }
                    self.isDeleteInProgress = false
                    self.deactivateUser()
                    self.preference.clearPreferenceSession()
                    self.preference.isOnboardShown = false
                    self.goToOnboardScreen()
                    LogD("UserProfileViewModel :: user deleted.")
                }.store(in: &cancelable)
        } else {
            LogD("UserProfileViewModel :: user not exists.")
        }
    }

    func deactivateUser() {
        if let user = preference.user {
            var newUser = user
            newUser.isActive = false

            let resizedImage = profileImage?.aspectFittedToHeight(200)
            let imageData = resizedImage?.jpegData(compressionQuality: 0.2)

            isDeleteInProgress = true
            userRepository.updateUserWithImage(imageData: imageData, newImageUrl: profileImageUrl, user: newUser)
                .sink { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.isDeleteInProgress = false
                        self?.showAlertFor(error)
                    }
                } receiveValue: { [weak self] user in
                    guard let self else { return }
                    self.isDeleteInProgress = false
                    self.preference.user = user
                }.store(in: &cancelable)
        }
    }

    private func goToOnboardScreen() {
        router?.popToRoot()
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
