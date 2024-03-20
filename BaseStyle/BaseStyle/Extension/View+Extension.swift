//
//  View.swift
//  UI
//
//  Created by Amisha Italiya on 13/02/24.
//

import UIKit
import SwiftUI

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
