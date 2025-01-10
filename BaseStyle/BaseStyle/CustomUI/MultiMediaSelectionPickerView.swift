//
//  MultiMediaSelectionPickerView.swift
//  Splito
//
//  Created by Nirali Sonani on 06/01/25.
//

import SwiftUI
import PhotosUI

public struct MultiMediaSelectionPickerView: UIViewControllerRepresentable {

    @Binding var isPresented: Bool

    let attachmentLimit: Int
    let onDismiss: ([Attachment]) -> Void

    public init(isPresented: Binding<Bool>, attachmentLimit: Int, onDismiss: @escaping ([Attachment]) -> Void) {
        self._isPresented = isPresented
        self.attachmentLimit = attachmentLimit
        self.onDismiss = onDismiss
    }

    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = attachmentLimit
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        picker.view.tintColor = UIColor(infoColor)
        return picker
    }

    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // Nothing to update here
    }

    public func makeCoordinator() -> MultiMediaSelectionPickerCoordinator {
        MultiMediaSelectionPickerCoordinator(isPresented: $isPresented, onDismiss: onDismiss)
    }

    public class MultiMediaSelectionPickerCoordinator: NSObject, PHPickerViewControllerDelegate {

        @Binding var isPresented: Bool

        let onDismiss: ([Attachment]) -> Void

        let imageRequestOptions = PHImageRequestOptions()

        public init(isPresented: Binding<Bool>, onDismiss: @escaping ([Attachment]) -> Void) {
            self._isPresented = isPresented
            self.onDismiss = onDismiss
        }

        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            imageRequestOptions.isSynchronous = true
            var attachments: [Attachment] = []
            let dispatchGroup = DispatchGroup()

            results.forEach { attachment in
                dispatchGroup.enter()

                if attachment.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    attachment.itemProvider.loadObject(ofClass: UIImage.self) { newImage, error in
                        if let selectedImage = newImage as? UIImage, let fileName = attachment.itemProvider.suggestedName {
                            let imageObject = Attachment(image: selectedImage.resizeImageIfNeededWhilePreservingAspectRatio(), name: fileName)
                            attachments.append(imageObject)
                        } else if let error = error {
                            print("MultiMediaSelectionPickerCoordinator: \(#function) Error in loading image: \(error)")
                        }
                        dispatchGroup.leave()
                    }
                } else if attachment.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    attachment.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in // it will return the temporary file address, so immediately retrieving video as data from the temporary url.
                        if let url = url, let fileName = attachment.itemProvider.suggestedName {
                            do {
                                let data = try Data(contentsOf: url)
                                let videoObject = Attachment(videoData: data, video: url, name: fileName)
                                attachments.append(videoObject)
                                try? FileManager.default.removeItem(at: url) // Clean up temporary file
                            } catch {
                                print("MultiMediaSelectionPickerCoordinator: \(#function) Error loading data from URL: \(error)")
                            }
                        } else if let error {
                            print("MultiMediaSelectionPickerCoordinator: \(#function) Error in loading video: \(error)")
                        }
                        dispatchGroup.leave()
                    }
                }
            }

            dispatchGroup.notify(queue: .main) {
                self.isPresented = false
                self.onDismiss(attachments)
            }
        }
    }
}

// MARK: - Struct to hold attachment data
public struct Attachment {
    public var id = UUID().uuidString
    public var image: UIImage?
    public var videoData: Data?
    public var video: URL?
    public var name: String

    public init(id: String = UUID().uuidString, image: UIImage? = nil, videoData: Data? = nil, video: URL? = nil, name: String) {
        self.id = id
        self.image = image
        self.videoData = videoData
        self.video = video
        self.name = name
    }
}
