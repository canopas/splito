//
//  ButtonStyleTapGestureModifier.swift
//  UI
//
//  Created by Amisha Italiya on 13/02/24.
//

import SwiftUI

struct ButtonStyleTapGestureModifier: ViewModifier {

    let action: () -> Void

    public func body(content: Content) -> some View {
        Button(action: action) {
            content
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

public struct ScaleButtonStyle: ButtonStyle {
    public func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

public extension ButtonStyle where Self == ScaleButtonStyle {
    static var scale: Self {
        return .init()
    }
}
