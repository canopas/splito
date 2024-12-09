//
//  PrimaryFloatingButton.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 11/03/24.
//

import SwiftUI

public struct PrimaryFloatingButton: View {

    private let text: String
    private let bottomPadding: CGFloat
    private var bgColor: Color
    private var textColor: Color
    private let isEnabled: Bool
    private let showLoader: Bool
    private let onClick: (() -> Void)?

    public init(text: String, bottomPadding: CGFloat = 24, textColor: Color = primaryLightText,
                bgColor: Color = primaryColor, isEnabled: Bool = true,
                showLoader: Bool = false, onClick: (() -> Void)? = nil) {
        self.text = text
        self.bottomPadding = bottomPadding
        self.textColor = textColor
        self.bgColor = bgColor
        self.isEnabled = isEnabled
        self.showLoader = showLoader
        self.onClick = onClick
    }

    public var body: some View {
        VStack(alignment: .center, spacing: 0) {
            VSpacer(10)

            PrimaryButton(text: text, textColor: textColor, bgColor: bgColor,
                          isEnabled: !showLoader && isEnabled,
                          showLoader: showLoader, onClick: onClick)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, bottomPadding)
        .background(FloatingButtonGradientBackground())
    }
}

public struct FloatingButtonGradientBackground: View {
    public init() {}

    public var body: some View {
        LinearGradient(colors: [surfaceColor, surfaceColor, surfaceColor, surfaceColor, surfaceColor, surfaceColor.opacity(1), surfaceColor.opacity(0)], startPoint: .bottom, endPoint: .top)
    }
}
