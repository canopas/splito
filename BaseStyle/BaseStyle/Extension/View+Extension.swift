//
//  View.swift
//  UI
//
//  Created by Amisha Italiya on 13/02/24.
//

import UIKit
import SwiftUI

public extension View {
    func cornerRadius(_ radius: Double) -> some View {
        clipShape( RoundedCorner(radius: radius) )
    }

    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }

    func addHapticEffect() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

public var isIpad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
}

public extension View {
    func onTouchGesture(_ action: @escaping () -> Void) -> some View {
        self.modifier(ButtonStyleTapGestureModifier(action: action))
    }

    func onTapGestureForced(count: Int = 1, perform action: @escaping () -> Void) -> some View {
        self
            .contentShape(Rectangle())
            .onTapGesture(count: count, perform: action)
    }
}

public extension View {
    @ViewBuilder func hidden(_ shouldHide: Bool) -> some View {
        switch shouldHide {
        case true: self.hidden()
        case false: self
        }
    }
}
