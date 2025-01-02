//
//  NavigationTitleTextView.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 02/10/24.
//

import SwiftUI

/// Used to show navigation bar title
public struct NavigationTitleTextView: View {

    let font: Font
    let foregroundColor: Color
    let text: String

    public init(text: String, font: Font = .Header2(), foregroundColor: Color = primaryText) {
        self.text = text
        self.font = font
        self.foregroundColor = foregroundColor
    }

    public var body: some View {
        Text(text.localized)
            .font(font)
            .foregroundStyle(foregroundColor)
    }
}
