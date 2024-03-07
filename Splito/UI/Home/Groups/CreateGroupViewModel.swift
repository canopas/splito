//
//  CreateGroupViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 06/03/24.
//

import UIKit
import Combine
import AVFoundation

class CreateGroupViewModel: BaseViewModel, ObservableObject {

    enum GroupType: String, CaseIterable {
        case trip = "Trip"
        case home = "Home"
        case couple = "Couple"
        case other = "Other"
    }

    @Published var groupName = ""
    @Published var showImagePicker = false
    @Published var showImagePickerOptions = false
    @Published private(set) var sourceTypeIsCamera = false

    @Published var imageName: String? = ""
    @Published var profileImage: UIImage?
    @Published var profileImageUrl: String = ""

    @Published var selectedGroupType: GroupType?

    private var cancellables: Set<AnyCancellable> = []

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
            profileImageUrl = ""
        }
    }

    func handleProfileTap() {
        showImagePickerOptions = true
    }

    func handleDoneAction() {
        // You can save the group details, dismiss the view, etc.
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
