//
//  NavigationBarTopView.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 07/08/24.
//

import SwiftUI

public struct NavigationBarTopView<LeadingButton: View, TrailingButton: View>: View {

    let title: String
    let leadingButton: LeadingButton
    let trailingButton: TrailingButton

    public init(title: String, leadingButton: LeadingButton, trailingButton: TrailingButton) {
        self.title = title
        self.leadingButton = leadingButton
        self.trailingButton = trailingButton
    }

    public var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 16)
                .fill(outlineColor)
                .frame(width: 40, height: 4)
                .padding(.top, 20)

            HStack(spacing: 0) {
                leadingButton

                Text(title.localized)
                    .font(.Header2())
                    .foregroundStyle(primaryText)

                Spacer()

                trailingButton
            }
            .padding(.top, 10)
        }
    }
}
