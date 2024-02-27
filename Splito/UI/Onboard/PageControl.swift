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
        ScrollView(showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<numberOfPages, id: \.self) { index in
                    if currentIndex == index {
                        capsulePageIndicator()
                    } else {
                        roundPageIndicationView()
                    }
                }
            }
        }
    }

    func roundPageIndicationView() -> some View {
        Circle()
            .fill(containerHigh)
            .frame(width: 10, height: 10, alignment: .center)
    }

    func capsulePageIndicator() -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(primaryColor)
                .frame(width: 26, height: 10, alignment: .center)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    PageControl(numberOfPages: 3, currentIndex: .constant(2))
}
