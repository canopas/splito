//
//  ImagePickerView.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 06/03/24.
//

import SwiftUI

public struct ImagePickerView: UIViewControllerRepresentable {
    @Environment(\.colorScheme) var colorScheme

    @Binding var image: UIImage?
    @Binding var fileName: String?
    @Binding var isPresented: Bool

    var cropOption: CropOption
    var sourceType: UIImagePickerController.SourceType = .photoLibrary

    public init(cropOption: CropOption, sourceType: UIImagePickerController.SourceType, image: Binding<UIImage?>, fileName: Binding<String?>, isPresented: Binding<Bool>) {
        self._image = image
        self.sourceType = sourceType
        self._fileName = fileName
        self._isPresented = isPresented
        self.cropOption = cropOption
    }

    public func makeCoordinator() -> ImagePickerViewCoordinator {
        return ImagePickerViewCoordinator(image: $image, fileName: $fileName, isPresented: $isPresented, cropOption: cropOption, isDarkMode: colorScheme == .dark)
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
    @Binding var fileName: String?
    @Binding var isPresented: Bool

    var cropOption: ImagePickerView.CropOption
    var isDarkMode: Bool

    init(image: Binding<UIImage?>, fileName: Binding<String?>, isPresented: Binding<Bool>, cropOption: ImagePickerView.CropOption, isDarkMode: Bool) {
        self._image = image
        self._fileName = fileName
        self._isPresented = isPresented
        self.cropOption = cropOption
        self.isDarkMode = isDarkMode
    }

    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let infoKey = cropOption == .square ? UIImagePickerController.InfoKey.editedImage : UIImagePickerController.InfoKey.originalImage
        let image = info[infoKey] as? UIImage
        var fileName: String?

        if let imageUrl = info[.imageURL] as? URL {
            fileName = imageUrl.lastPathComponent
        }

        if cropOption == .custom {
//            let viewController = UIHostingController(rootView: ImageCropView(image: image, fileName: fileName, isDarkModeEnabled: isDarkMode, updateImageCallBack: updateImageCallBack(_:_:)))
//
//            picker.present(viewController, animated: true)
        } else {
            updateImageCallBack(fileName, image)
        }
    }

    func updateImageCallBack(_ fileName: String?, _ image: UIImage?) {
        if let image {
            let resizedImage = image.resizeImageIfNeededWhilePreservingAspectRatio()
            self.image = resizedImage
        }
        if let fileName {
            self.fileName = fileName
        }
        self.isPresented = false
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.isPresented = false
    }
}
