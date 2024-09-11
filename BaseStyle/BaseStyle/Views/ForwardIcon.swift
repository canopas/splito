//
//  ForwardIcon.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 08/04/24.
//

import SwiftUI

public struct ForwardIcon: View {

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "chevron.right")
                .font(.system(size: 12).weight(.bold))
                .aspectRatio(contentMode: .fit)
        }
        .foregroundStyle(secondaryText)
        .frame(width: 26, height: 26, alignment: .center)
    }
}
