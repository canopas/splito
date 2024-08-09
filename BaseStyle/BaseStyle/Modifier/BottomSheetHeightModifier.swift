//
//  BottomSheetHeightModifier.swift
//  BaseStyle
//
//  Created by Nirali Sonani on 07/08/24.
//

import SwiftUI

public struct BottomSheetHeightModifier: ViewModifier {
    @Binding var height: CGFloat

    public init(height: Binding<CGFloat>) {
        self._height = height
    }

    public func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo -> Color in
                DispatchQueue.main.async {
                    height = geo.size.height
                }
                return Color.clear
            }
        )
    }
}
