//
//  CreateGroupViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 06/03/24.
//

import Data
import UIKit
import Combine
import BaseStyle
import AVFoundation
import FirebaseFirestoreInternal

class CreateGroupViewModel: BaseViewModel, ObservableObject {

    enum GroupType: String, CaseIterable {
        case trip = "Trip"
        case home = "Home"
        case couple = "Couple"
        case other = "Other"
    }

    @Inject var preference: SplitoPreference
    @Inject var storageManager: StorageManager
    @Inject var groupRepository: GroupRepository

    @Published var sourceTypeIsCamera = false
    @Published var showImagePicker = false
    @Published var showImagePickerOptions = false

    @Published var groupName = ""
    @Published var profileImage: UIImage?
    @Published var profileImageUrl: String?

    @Published var group: Groups?
    @Published var currentState: ViewState = .initial

    let router: Router<AppRoute>
    var isOpenForEdit: Bool = false

    init(router: Router<AppRoute>, group: Groups? = nil) {
        self.router = router
        self.group = group
        self.groupName = group?.name ?? ""
        self.profileImageUrl = group?.imageUrl
        super.init()
    }

    private func checkCameraPermission(authorized: @escaping (() -> Void)) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    authorized()
                }
            }
            return
        case .restricted, .denied:
            showAlertFor(alert: .init(title: "Important!", message: "Camera access is required to take picture for your profile",
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
        }
    }

    func handleProfileTap() {
        showImagePickerOptions = true
    }

    /// Create a new group
    func handleDoneAction() {
        if let group {
            updateGroup(group: group)
        } else {
            createGroup()
        }
    }

    private func createGroup() {
        currentState = .loading
        let userId = preference.user?.id ?? ""
        let group = Groups(name: groupName.capitalized, createdBy: userId, members: [userId], imageUrl: nil, createdAt: Timestamp())

        let resizedImage = profileImage?.aspectFittedToHeight(200)
        let imageData = resizedImage?.jpegData(compressionQuality: 0.2)

        groupRepository.createGroup(group: group, imageData: imageData)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.currentState = .initial
                    self?.showAlertFor(error)
                }
            } receiveValue: { id in
                self.goToGroupHome(groupId: id)
            }.store(in: &cancelable)
    }

    private func updateGroup(group: Groups) {
        currentState = .loading

        var newGroup = group
        newGroup.name = groupName

        let resizedImage = profileImage?.aspectFittedToHeight(200)
        let imageData = resizedImage?.jpegData(compressionQuality: 0.2)

        groupRepository.updateGroupWithImage(imageData: imageData, group: newGroup)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.currentState = .initial
                    self?.showAlertFor(error)
                }
            } receiveValue: { _ in
                self.router.pop()
            }.store(in: &cancelable)
    }

    private func goToGroupHome(groupId: String) {
        self.router.pop()
        self.router.push(.GroupHomeView(groupId: groupId))
    }
}

// MARK: - Action sheet Struct
extension CreateGroupViewModel {
    enum ActionsOfSheet {
        case camera
        case gallery
        case remove
    }
}

// MARK: - View's State
extension CreateGroupViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
