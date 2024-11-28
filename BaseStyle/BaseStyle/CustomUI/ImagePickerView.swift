//
//  ImagePickerView.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 06/03/24.
//

import SwiftUI

public struct ImagePickerView: UIViewControllerRepresentable {

    @Binding var image: UIImage?
    @Binding var isPresented: Bool

    var cropOption: CropOption
    var sourceType: UIImagePickerController.SourceType = .photoLibrary

    public init(cropOption: CropOption, sourceType: UIImagePickerController.SourceType,
                image: Binding<UIImage?>, isPresented: Binding<Bool>) {
        self._image = image
        self.sourceType = sourceType
        self._isPresented = isPresented
        self.cropOption = cropOption
    }

    public func makeCoordinator() -> ImagePickerViewCoordinator {
        return ImagePickerViewCoordinator(image: $image, isPresented: $isPresented, cropOption: cropOption)
    }

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let pickerController = UIImagePickerController()
        pickerController.allowsEditing = cropOption == .square
        pickerController.sourceType = sourceType
        pickerController.delegate = context.coordinator
        if sourceType == .camera {
            pickerController.cameraDevice = .front
        }
        return pickerController
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Nothing to update here
    }

    public enum CropOption {
        case square
        case custom
        case none
    }
}

public class ImagePickerViewCoordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    @Binding var image: UIImage?
    @Binding var isPresented: Bool

    var cropOption: ImagePickerView.CropOption

    init(image: Binding<UIImage?>, isPresented: Binding<Bool>, cropOption: ImagePickerView.CropOption) {
        self._image = image
        self._isPresented = isPresented
        self.cropOption = cropOption
    }

    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let infoKey = cropOption == .square ? UIImagePickerController.InfoKey.editedImage : UIImagePickerController.InfoKey.originalImage
        let image = info[infoKey] as? UIImage

        updateImageCallBack(image)
    }

    func updateImageCallBack(_ image: UIImage?) {
        if let image {
            let resizedImage = image.resizeImageIfNeededWhilePreservingAspectRatio()
            self.image = resizedImage
        }
        self.isPresented = false
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.isPresented = false
    }
}
