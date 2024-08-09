//
//  ScrollToTopButton.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 12/07/24.
//

import SwiftUI

public struct ScrollToTopButton: View {

    let icon: String
    let iconColor: Color
    let bgColor: Color
    let showWithAnimation: Bool
    let padding: CGFloat
    let size: (width: CGFloat, height: CGFloat)
    let isFirstGroupCell: Bool

    let onClick: (() -> Void)?

    @State private var shouldRotate = false
    @State private var rotationAngle: Double = 0

    public init(icon: String = "arrow.up", iconColor: Color = primaryDarkText, bgColor: Color = primaryColor,
                showWithAnimation: Bool = false, size: (width: CGFloat, height: CGFloat) = (16, 16),
                padding: CGFloat = 10, isFirstGroupCell: Bool = false, onClick: (() -> Void)? = nil) {
        self.icon = icon
        self.iconColor = iconColor
        self.bgColor = bgColor
        self.showWithAnimation = showWithAnimation
        self.size = size
        self.padding = padding
        self.isFirstGroupCell = isFirstGroupCell
        self.onClick = onClick
    }

    public var body: some View {
        Button(action: onTap) {
            Image(systemName: icon)
                .resizable()
                .fontWeight(.semibold)
                .foregroundStyle(iconColor)
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)
                .rotationEffect(.degrees(shouldRotate ? 180 : 360))
                .animation(Animation.easeInOut(duration: 0.3), value: shouldRotate)
                .padding(padding)
                .background(bgColor)
                .clipShape(Circle())
        }
        .buttonStyle(.scale)
        .onAppear {
            if isFirstGroupCell {
                if showWithAnimation {
                    shouldRotate = true
                }
                onClick?()
            }
        }
    }

    private func onTap() {
        if showWithAnimation {
            shouldRotate.toggle()
        }
        addHapticEffect()
        onClick?()
    }
}
