//
//  DismissButton.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 22/02/24.
//

import SwiftUI

public struct DismissButton: View {

    private let iconName: String
    private let iconSize: (CGFloat, weight: Font.Weight)
    private let padding: (horizontal: CGFloat, vertical: CGFloat)
    private let borderColor: Color
    private let foregroundColor: Color
    private let backgroundColor: Color?
    private let onDismissAction: (() -> Void)?

    public init(iconName: String = "multiply", iconSize: (CGFloat, weight: Font.Weight) = (24, .regular),
                padding: (horizontal: CGFloat, vertical: CGFloat) = (0, 0),
                borderColor: Color = .clear, foregroundColor: Color = secondaryText,
                backgroundColor: Color? = nil, onDismissAction: (() -> Void)? = nil) {
        self.iconName = iconName
        self.iconSize = iconSize
        self.padding = padding
        self.borderColor = borderColor
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.onDismissAction = onDismissAction
    }

    public var body: some View {
        Button(action: {
            onDismissAction?()
        }, label: {
            Image(systemName: iconName)
                .font(.system(size: iconSize.0).weight(iconSize.weight))
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, padding.horizontal)
                .padding(.vertical, padding.vertical)
                .background(backgroundColor)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(borderColor, lineWidth: 1)
                }
        })
    }
}
