//
//  CreateGroupViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 06/03/24.
//

import Data
import UIKit
import BaseStyle
import AVFoundation
import FirebaseFirestore

class CreateGroupViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var storageManager: StorageManager
    @Inject private var groupRepository: GroupRepository

    @Published var showImagePicker = false
    @Published var showImagePickerOptions = false
    @Published private(set) var showLoader = false
    @Published private(set) var sourceTypeIsCamera = false

    @Published var groupName = ""
    @Published var profileImage: UIImage?
    @Published var profileImageUrl: String?

    @Published var group: Groups?

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
                DispatchQueue.main.async {
                    if granted {
                        authorized()
                    }
                }
            }
            return
        case .restricted, .denied:
            showAlertFor(alert: .init(title: "Important!", message: "Camera access is required to take picture for your group profile",
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

    func handleDoneAction() async -> Bool {
        if let group {
            await updateGroup(group: group)
        } else {
            await createGroup()
        }
    }

    func showSaveFailedToast() {
        self.showToastFor(toast: ToastPrompt(type: .error, title: "Oops", message: "Failed to save group."))
    }

    private func createGroup() async -> Bool {
        guard let userId = preference.user?.id else { return false }

        let memberBalance = GroupMemberBalance(id: userId, balance: 0, totalSummary: [])
        let group = Groups(name: groupName.trimming(spaces: .leadingAndTrailing), createdBy: userId, updatedBy: userId, imageUrl: nil,
                           members: [userId], balances: [memberBalance], createdAt: Timestamp(), updatedAt: Timestamp())

        let resizedImage = profileImage?.aspectFittedToHeight(200)
        let imageData = resizedImage?.jpegData(compressionQuality: 0.2)

        do {
            showLoader = true
            let group = try await groupRepository.createGroup(group: group, imageData: imageData)
            NotificationCenter.default.post(name: .addGroup, object: group)
            showLoader = false
            return true
        } catch {
            showLoader = false
            showToastForError()
            return false
        }
    }

    private func updateGroup(group: Groups) async -> Bool {
        guard let userId = preference.user?.id else { return false }

        var newGroup = group
        newGroup.name = groupName.trimming(spaces: .leadingAndTrailing)
        newGroup.updatedBy = userId
        newGroup.updatedAt = Timestamp()

        let resizedImage = profileImage?.aspectFittedToHeight(200)
        let imageData = resizedImage?.jpegData(compressionQuality: 0.2)

        do {
            self.showLoader = true
            let updatedGroup = try await groupRepository.updateGroupWithImage(imageData: imageData, newImageUrl: profileImageUrl,
                                                                              group: newGroup, oldGroupName: group.name)
            NotificationCenter.default.post(name: .updateGroup, object: updatedGroup)
            showLoader = false
            return true
        } catch {
            showLoader = false
            showToastForError()
            return false
        }
    }
}

// MARK: - Image Picker Action sheet
enum ActionsOfSheet {
    case camera
    case gallery
    case remove
}
