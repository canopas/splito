//
//  CheckmarkButton.swift
//  BaseStyle
//
//  Created by Nirali Sonani on 25/07/24.
//

import SwiftUI

public struct CheckmarkButton: View {

    private let showLoader: Bool
    private let iconSize: (width: CGFloat, height: CGFloat)
    private let padding: (edges: Edge.Set, value: CGFloat)

    private let onClick: (() -> Void)?

    public init(showLoader: Bool = false, iconSize: (width: CGFloat, height: CGFloat) = (26, 34),
                padding: (edges: Edge.Set, value: CGFloat) = (.all, 2), onClick: (() -> Void)? = nil) {
        self.showLoader = showLoader
        self.iconSize = iconSize
        self.padding = padding
        self.onClick = onClick
    }

    public var body: some View {
        if showLoader {
            ImageLoaderView(tintColor: primaryColor)
        } else {
            Button(action: {
                onClick?()
            }, label: {
                Image(.checkmarkIcon)
                    .resizable()
                    .frame(width: iconSize.width, height: iconSize.height)
                    .padding(padding.edges, padding.value)
            })
        }
    }
}
