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
import FirebaseFirestore

class CreateGroupViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var storageManager: StorageManager
    @Inject var groupRepository: GroupRepository

    @Published var showImagePicker = false
    @Published var showImagePickerOptions = false
    @Published private(set) var showLoader = false
    @Published private(set) var sourceTypeIsCamera = false

    @Published var groupName = ""
    @Published var profileImage: UIImage?
    @Published var profileImageUrl: String?

    @Published var group: Groups?
    @Published var currentState: ViewState = .initial

    private let router: Router<AppRoute>

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
            profileImageUrl = nil
        }
    }

    func handleProfileTap() {
        showImagePickerOptions = true
    }

    func handleDoneAction() async {
        if let group {
            await updateGroup(group: group)
        } else {
            await createGroup()
        }
    }

    private func createGroup() async {
        showLoader = true

        let userId = preference.user?.id ?? ""
        let memberBalance = GroupMemberBalance(id: userId, balance: 0, totalSummary: [])
        let group = Groups(name: groupName.trimming(spaces: .leadingAndTrailing), createdBy: userId,
                           imageUrl: nil, members: [userId], balances: [memberBalance], createdAt: Timestamp())

        let resizedImage = profileImage?.aspectFittedToHeight(200)
        let imageData = resizedImage?.jpegData(compressionQuality: 0.2)

        do {
            let newGroup = try await groupRepository.createGroup(group: group, imageData: imageData)
            showLoader = false
            NotificationCenter.default.post(name: .addGroup, object: newGroup)
        } catch {
            currentState = .initial
            showLoader = false
            showAlertFor(error as! ServiceError)
        }
    }

    private func updateGroup(group: Groups) async {
        self.showLoader = true

        var newGroup = group
        newGroup.name = groupName.trimming(spaces: .leadingAndTrailing)

        let resizedImage = profileImage?.aspectFittedToHeight(200)
        let imageData = resizedImage?.jpegData(compressionQuality: 0.2)

        do {
            let updatedGroup = try await groupRepository.updateGroupWithImage(imageData: imageData, newImageUrl: profileImageUrl, group: newGroup)
            showLoader = false
            NotificationCenter.default.post(name: .updateGroup, object: updatedGroup)
        } catch {
            currentState = .initial
            showLoader = false
            showAlertFor(error as! ServiceError)
        }
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
