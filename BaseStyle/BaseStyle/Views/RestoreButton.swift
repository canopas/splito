//
//  RestoreButton.swift
//  Splito
//
//  Created by Nirali Sonani on 24/10/24.
//

import SwiftUI

public struct RestoreButton: View {

    let onClick: () -> Void

    public init(onClick: @escaping () -> Void) {
        self.onClick = onClick
    }

    public var body: some View {
        Button(action: onClick) {
            Text("Restore")
                .font(.subTitle3())
                .foregroundStyle(primaryText)
        }
    }
}
