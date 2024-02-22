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
}
