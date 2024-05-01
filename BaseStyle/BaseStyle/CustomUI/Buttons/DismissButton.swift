//
//  DismissButton.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 22/02/24.
//

import SwiftUI

public struct DismissButton: View {

    private let iconSize: (CGFloat, weight: Font.Weight)
    private let opacity: Double
    private let padding: CGFloat
    private let borderColor: Color
    private let foregroundColor: Color
    private let backgroundColor: Color?
    private let onDismissAction: (() -> Void)?

    public init(iconSize: (CGFloat, weight: Font.Weight) = (24, .regular), opacity: Double = 1, padding: CGFloat = 0, borderColor: Color = .clear, foregroundColor: Color = secondaryText, backgroundColor: Color? = nil, onDismissAction: (() -> Void)? = nil) {
        self.iconSize = iconSize
        self.opacity = opacity
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
            Image(systemName: "multiply")
                .font(.system(size: iconSize.0).weight(iconSize.weight))
                .foregroundStyle(foregroundColor)
                .padding(padding)
                .background(backgroundColor)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(borderColor, lineWidth: 1)
                }
                .opacity(opacity)
        })
        .buttonStyle(.scale)
    }
}
