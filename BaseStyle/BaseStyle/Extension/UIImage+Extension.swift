//
//  UIImage+Extension.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 06/03/24.
//

import UIKit

public extension UIImage {
    func resizeImageIfNeededWhilePreservingAspectRatio(maxWidth: CGFloat = 1920, maxHeight: CGFloat = 1080) -> UIImage {
        if size.width < maxWidth && size.height < maxHeight { return self }

        let widthRatio = maxWidth / size.width
        let heightRatio = maxHeight / size.height

        let scaleFactor = min(widthRatio, heightRatio)
        let scaledImageSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: scaledImageSize, format: format)

        let scaledImage = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: scaledImageSize))
        }
        return scaledImage
    }

    func aspectFittedToHeight(_ newHeight: CGFloat) -> UIImage {
        let scale = newHeight / self.size.height
        let newWidth = self.size.width * scale
        let newSize = CGSize(width: newWidth, height: newHeight)
        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// Converts the UIImage to JPEG data with the highest quality
public extension UIImage {
    var jpegRepresentationData: Data? {
        self.jpegData(compressionQuality: 1.0)
    }
}
