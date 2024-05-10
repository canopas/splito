//
//  SectionHeaderView.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 23/02/24.
//

import SwiftUI

public struct HeaderTextView: View {

    private let title: String
    private let font: Font
    private let foregroundColor: Color
    private let lineSpacing: CGFloat
    private let alignment: Alignment
    private let shouldGrow: Bool

    public init(title: String, font: Font = .Header2(), foregroundColor: Color = primaryText, lineSpacing: CGFloat = 4, shouldGrow: Bool = true, alignment: Alignment = .leading) {
        self.title = title
        self.font = font
        self.foregroundColor = foregroundColor
        self.lineSpacing = lineSpacing
        self.shouldGrow = shouldGrow
        self.alignment = alignment
    }

    public var body: some View {
        Text(title.localized)
            .font(font)
            .foregroundStyle(foregroundColor)
            .tracking(-0.4)
            .lineSpacing(lineSpacing)
            .frame(maxWidth: shouldGrow ? .infinity : nil, alignment: alignment)
    }
}

public struct SubtitleTextView: View {

    private let text: String
    private let fontSize: Font
    private let fontColor: Color
    private let lineLimit: Int?
    private let letterTracking: CGFloat

    public init(text: String, fontSize: Font = .subTitle2(), fontColor: Color = secondaryText, lineLimit: Int? = nil, letterTracking: CGFloat = -0.4) {
        self.text = text
        self.fontSize = fontSize
        self.fontColor = fontColor
        self.lineLimit = lineLimit
        self.letterTracking = letterTracking
    }

    public var body: some View {
        Text(text.localized)
            .font(fontSize)
            .foregroundStyle(fontColor)
            .tracking(letterTracking)
            .lineLimit(lineLimit)
    }
}
