//
//  BackButton.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 23/07/24.
//

import SwiftUI

public struct BackButton: View {

    let iconColor: Color
    let size: (width: CGFloat, height: CGFloat)
    let padding: (horizontal: CGFloat, vertical: CGFloat)

    let onClick: (() -> Void)?

    public init(size: (width: CGFloat, height: CGFloat) = (20, 20), iconColor: Color = primaryDarkText,
                padding: (horizontal: CGFloat, vertical: CGFloat) = (10, 10), onClick: (() -> Void)? = nil) {
        self.size = size
        self.iconColor = iconColor
        self.padding = padding
        self.onClick = onClick
    }

    public var body: some View {
        Button {
            onClick?()
        } label: {
            Image(systemName: "chevron.left")
                .resizable()
                .scaledToFit()
                .foregroundStyle(iconColor)
                .frame(width: size.width, height: size.height)
                .padding(.horizontal, padding.horizontal)
                .padding(.vertical, padding.vertical)
        }
    }
}
