//
//  ScrollToTopButton.swift
//  BaseStyle
//
//  Created by Nirali Sonani on 12/07/24.
//

import SwiftUI

public struct ScrollToTopButton: View {
    private let onClick: (() -> Void)?

    public init(onClick: (() -> Void)? = nil) {
        self.onClick = onClick
    }

    public var body: some View {
        VStack(spacing: 0) {
            VSpacer()

            Button(action: {
                onClick?()
            }, label: {
                Image(systemName: "chevron.up")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(surfaceLightColor)
                    .padding(10)
                    .background(primaryColor)
                    .clipShape(Circle())
                    .padding([.trailing, .bottom], 16)
            })
            .buttonStyle(.scale)
        }
        .frame(maxWidth: .infinity, alignment: .bottomTrailing)
    }
}
