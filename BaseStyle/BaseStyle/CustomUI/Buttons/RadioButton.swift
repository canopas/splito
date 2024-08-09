//
//  RadioButton.swift
//  BaseStyle
//
//  Created by Nirali Sonani on 25/07/24.
//

import SwiftUI

public struct RadioButton: View {

    var isSelected: Bool

    var action: () -> Void

    public init(isSelected: Bool, action: @escaping () -> Void) {
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(isSelected ? primaryColor : outlineColor, lineWidth: 1.8)
                    .frame(width: 20, height: 20)

                if isSelected {
                    Circle()
                        .fill(primaryColor)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
