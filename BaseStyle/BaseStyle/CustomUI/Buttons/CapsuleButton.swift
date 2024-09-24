//
//  CapsuleButton.swift
//  BaseStyle
//
//  Created by Nirali Sonani on 23/09/24.
//

import SwiftUI

public struct CapsuleButton: View {

    private let buttonName: String
    private let paddingHr: CGFloat
    private let paddingVr: CGFloat
    private let isEnabled: Bool
    private let onClick: (() -> Void)?

    public init(buttonName: String, isEnabled: Bool = true, paddingHr: CGFloat = 73, paddingVr: CGFloat = 12, onClick: (() -> Void)?) {
        self.buttonName = buttonName
        self.paddingHr = paddingHr
        self.paddingVr = paddingVr
        self.isEnabled = isEnabled
        self.onClick = onClick
    }

    public var body: some View {
        Button {
            if isEnabled {
                onClick?()
            }
        } label: {
            HStack(spacing: 5) {
                Text(buttonName)
                    .font(.buttonText())
                    .foregroundColor(primaryLightText)
            }
            .padding(.horizontal, paddingHr)
            .padding(.vertical, paddingVr)
            .background(primaryColor)
            .cornerRadius(12)
        }
        .buttonStyle(.scale)
        .disabled(!isEnabled)
    }
}
