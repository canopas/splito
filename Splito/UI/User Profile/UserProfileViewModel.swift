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

    @Inject var preference: SplitoPreference
    @Inject var userRepository: UserRepository

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

    @Published private(set) var currentState: ViewState = .loading

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>, isOpenedFromOnboard: Bool) {
        self.router = router
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
            profileImageUrl = user.imageUrl ?? ""
        }
        currentState = .initial
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
            profileImageUrl = ""
        }
    }

    func updateUserProfile() {
        if let user = preference.user {
            self.currentState = .loading
            let newUser = AppUser(id: user.id, firstName: firstName, lastName: lastName,
                                  emailId: email, phoneNumber: phone, loginType: user.loginType)

            userRepository.updateUser(user: newUser)
                .sink { [weak self] completion in
                    switch completion {
                    case .finished:
                        return
                    case .failure(let error):
                        self?.currentState = .initial
                        self?.showToastFor(error)
                    }
                } receiveValue: { [weak self] _ in
                    guard let self else { return }
                    self.currentState = .initial
                    self.preference.user = newUser

                    if self.isOpenedFromOnboard {
                        self.goToHome()
                    }
                }.store(in: &cancelable)
        }
    }

    func goToHome() {
        router.popToRoot()
        router.updateRoot(root: .HomeView)
    }

    func handleDeleteAction() {
        if let user = preference.user {
            userRepository.deleteUser(id: user.id)
                .sink { [weak self] completion in
                    switch completion {
                    case .finished:
                        return
                    case .failure(let error):
                        self?.currentState = .initial
                        self?.showToastFor(error)
                    }
                } receiveValue: { _ in
                    print("UserProfileViewModel :: user deleted.")
                }.store(in: &cancelable)
        } else {
            print("UserProfileViewModel :: user not exists.")
        }
    }
}

// MARK: - View's State
extension UserProfileViewModel {
    enum ViewState {
        case initial
        case loading
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
