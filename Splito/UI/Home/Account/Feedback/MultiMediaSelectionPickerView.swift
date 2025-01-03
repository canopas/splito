//
//  MultiMediaSelectionPickerView.swift
//  Splito
//
//  Created by Nirali Sonani on 03/01/25.
//

import SwiftUI
import PhotosUI
import Data
import BaseStyle

public struct MultiMediaSelectionPickerView: UIViewControllerRepresentable {

    @Binding var isPresented: Bool

    let onDismiss: ([Attachment]) -> Void

    public init(isPresented: Binding<Bool>, onDismiss: @escaping ([Attachment]) -> Void) {
        self._isPresented = isPresented
        self.onDismiss = onDismiss
    }

    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 5
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

        let imageManager = PHImageManager.default()
        let imageRequestOptions = PHImageRequestOptions()

        public init(isPresented: Binding<Bool>, onDismiss: @escaping ([Attachment]) -> Void) {
            self._isPresented = isPresented
            self.onDismiss = onDismiss
        }

        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            imageRequestOptions.isSynchronous = true
            var attachments: [Attachment] = []

            let dispatchGroup = DispatchGroup()

            for attachment in results {
                if attachment.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    dispatchGroup.enter()

                    attachment.itemProvider.loadObject(ofClass: UIImage.self) { newImage, error in
                        if let selectedImage = newImage as? UIImage, let fileName = attachment.itemProvider.suggestedName {
                            let imageObject = Attachment(image: selectedImage.resizeImageIfNeededWhilePreservingAspectRatio(), name: fileName)
                            attachments.append(imageObject)
                        } else if let error = error {
                            LogE("MultiMediaSelectionPickerCoordinator: \(#function) Error in loading image: \(error)")
                        }
                        dispatchGroup.leave()
                    }
                } else if attachment.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    dispatchGroup.enter()

                    attachment.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in // it will return the temporary file address, so immediately retrieving video as data from the temporary url.
                        if let url = url, let fileName = attachment.itemProvider.suggestedName {
                            do {
                                let data = try Data(contentsOf: url)
                                let videoObject = Attachment(videoData: data, video: url, name: fileName)
                                attachments.append(videoObject)
                            } catch {
                                LogE("MultiMediaSelectionPickerCoordinator: \(#function) Error loading data from URL: \(error)")
                            }
                        } else if let error = error {
                            LogE("MultiMediaSelectionPickerCoordinator: \(#function) Error in loading video: \(error)")
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
