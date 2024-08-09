//
//  PageControl.swift
//  Splito
//
//  Created by Amisha Italiya on 20/02/24.
//

import Foundation
import SwiftUI
import BaseStyle

struct PageControl: View {

    var numberOfPages: Int

    @Binding public var currentIndex: Int

    var body: some View {
        ScrollView {
            HStack(spacing: 4) {
                ForEach(0..<numberOfPages, id: \.self) { index in
                    if currentIndex == index {
                        capsulePageIndicator()
                    } else {
                        roundPageIndicationView()
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    func roundPageIndicationView() -> some View {
        Rectangle()
            .fill(outlineColor)
            .frame(width: 16, height: 8, alignment: .center)
            .clipShape(Capsule())
    }

    func capsulePageIndicator() -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(primaryDarkColor)
                .frame(width: 40, height: 8, alignment: .center)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    PageControl(numberOfPages: 3, currentIndex: .constant(2))
}
