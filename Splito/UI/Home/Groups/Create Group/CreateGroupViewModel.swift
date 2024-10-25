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
    @Inject private var activityLogRepository: ActivityLogRepository

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

    func handleDoneAction(completion: @escaping (Bool) -> Void) async {
        if let group {
            return await updateGroup(group: group, completion: completion)
        } else {
            return await createGroup(completion: completion)
        }
    }

    private func createGroup(completion: (Bool) -> Void) async {
        guard let userId = preference.user?.id else { return }

        let memberBalance = GroupMemberBalance(id: userId, balance: 0, totalSummary: [])
        let group = Groups(name: groupName.trimming(spaces: .leadingAndTrailing), createdBy: userId, updatedBy: userId,
                           imageUrl: nil, members: [userId], balances: [memberBalance], createdAt: Timestamp())

        let resizedImage = profileImage?.aspectFittedToHeight(200)
        let imageData = resizedImage?.jpegData(compressionQuality: 0.2)

        do {
            showLoader = true
            let group = try await groupRepository.createGroup(group: group, imageData: imageData)
            NotificationCenter.default.post(name: .addGroup, object: group)
            await addLogForCreateGroup(group: group)
            showLoader = false
            completion(true)
        } catch {
            showLoader = false
            completion(false)
            showToastForError()
        }
    }

    private func addLogForCreateGroup(group: Groups) async {
        guard let userId = preference.user?.id else {
            showLoader = false
            return
        }

        var errors: [Error] = []
        await addActivityLog(group: group, type: .groupCreated, memberId: userId, errors: &errors)

        handleActivityLogErrors(errors)
    }

    private func updateGroup(group: Groups, completion: (Bool) -> Void) async {
        guard let userId = preference.user?.id else { return }

        var newGroup = group
        newGroup.name = groupName.trimming(spaces: .leadingAndTrailing)
        newGroup.updatedBy = userId

        let resizedImage = profileImage?.aspectFittedToHeight(200)
        let imageData = resizedImage?.jpegData(compressionQuality: 0.2)

        do {
            self.showLoader = true
            let updatedGroup = try await groupRepository.updateGroupWithImage(imageData: imageData, newImageUrl: profileImageUrl, group: newGroup)
            NotificationCenter.default.post(name: .updateGroup, object: updatedGroup)
            await addLogForUpdateGroup(updatedGroup: updatedGroup)
            showLoader = false
            completion(true)
        } catch {
            showLoader = false
            completion(false)
            showToastForError()
        }
    }

    private func addLogForUpdateGroup(updatedGroup: Groups) async {
        guard let group else {
            showLoader = false
            return
        }

        let currentGroupName = group.name
        let currentImageUrl = group.imageUrl
        let hasNameChanged = currentGroupName.trimmingCharacters(in: .whitespacesAndNewlines) != updatedGroup.name
        let hasImageChanged = currentImageUrl != updatedGroup.imageUrl

        if !hasNameChanged && !hasImageChanged {
            showLoader = false
            return
        }

        var errors: [Error] = []
        let type: ActivityType = (group.imageUrl != updatedGroup.imageUrl && group.name != updatedGroup.name) ? .groupUpdated : group.imageUrl != updatedGroup.imageUrl ? .groupImageUpdated : .groupNameUpdated

        await withTaskGroup(of: Void.self) { groupTasks in
            for memberId in Set(updatedGroup.members) {
                groupTasks.addTask { [weak self] in
                    await self?.addActivityLog(group: updatedGroup, type: type, memberId: memberId, previousGroupName: (type == .groupNameUpdated || type == .groupUpdated) ? group.name : nil, errors: &errors)
                }
            }
        }

        handleActivityLogErrors(errors)
    }

    private func addActivityLog(group: Groups, type: ActivityType, memberId: String, previousGroupName: String? = nil, errors: inout [Error]) async {
        guard let user = preference.user else {
            showLoader = false
            return
        }

        if let activity = createActivityLogForGroup(context: ActivityLogContext(group: group, type: type, memberId: memberId, currentUser: user, previousGroupName: previousGroupName)) {
            do {
                try await activityLogRepository.addActivityLog(userId: memberId, activity: activity)
            } catch {
                errors.append(error)
            }
        }
    }

    // MARK: - Error Handling
    private func handleActivityLogErrors(_ errors: [Error]) {
        if !errors.isEmpty {
            showLoader = false
            showToastForError()
        }
    }
}

// MARK: - Image Picker Action sheet
enum ActionsOfSheet {
    case camera
    case gallery
    case remove
}
