//
//  MediaPickerOptionsView.swift
//  BaseStyle
//
//  Created by Nirali Sonani on 03/01/25.
//

import SwiftUI

public struct MediaPickerOptionsView: View {

    public let image: UIImage?
    public let imageUrl: String?
    public let withRemoveAllOption: Bool

    public let handleActionSelection: (ActionsOfSheet) -> Void

    public init(image: UIImage? = nil, imageUrl: String? = nil, withRemoveAllOption: Bool = false,
                handleActionSelection: @escaping (ActionsOfSheet) -> Void) {
        self.image = image
        self.imageUrl = imageUrl
        self.withRemoveAllOption = withRemoveAllOption
        self.handleActionSelection = handleActionSelection
    }

    public var body: some View {
        if !withRemoveAllOption {
            Button("Take a picture") {
                handleActionSelection(.camera)
            }
        }

        Button(withRemoveAllOption ? "Gallery" : "Choose from Library") {
            handleActionSelection(.gallery)
        }

        if withRemoveAllOption || (image != nil || (imageUrl != nil && !(imageUrl?.isEmpty ?? false))) {
            Button(withRemoveAllOption ? "Remove all" : "Remove", role: .destructive) {
                handleActionSelection(withRemoveAllOption ? .removeAll : .remove)
            }
        }
    }
}

// MARK: - Media Picker Action sheet
public enum ActionsOfSheet {
    case camera
    case gallery
    case remove
    case removeAll
}
