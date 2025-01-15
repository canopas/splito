//
//  SectionHeaderView.swift
//  Splito
//
//  Created by Nirali Sonani on 09/01/25.
//

import SwiftUI

public struct SectionHeaderView: View {

    let text: String
    let font: Font
    let textColor: Color
    let alignment: Alignment
    let horizontalPadding: CGFloat

    public init(text: String, font: Font = .subTitle3(), textColor: Color = disableText,
                alignment: Alignment = .leading, horizontalPadding: CGFloat = 16) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.alignment = alignment
        self.horizontalPadding = horizontalPadding
    }

    public var body: some View {
        Text(text.localized)
            .font(font)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, alignment: alignment)
            .padding(.horizontal, horizontalPadding)
    }
}
