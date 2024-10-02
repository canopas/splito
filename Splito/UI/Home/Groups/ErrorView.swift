//
//  ErrorView.swift
//  Splito
//
//  Created by Amisha Italiya on 23/09/24.
//

import SwiftUI
import BaseStyle

struct ErrorView: View {

    let isForNoInternet: Bool

    let onClick: (() -> Void)?

    init(isForNoInternet: Bool, onClick: (() -> Void)?) {
        self.isForNoInternet = isForNoInternet
        self.onClick = onClick
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Image(isForNoInternet ? .noInternetIcon : .somethingWentWrong)

                    VSpacer(40)

                    VStack(spacing: 16) {
                        Text(isForNoInternet ? "No internet!" : "Something went wrong!")
                            .font(.Header1())
                            .foregroundColor(primaryText)
                            .multilineTextAlignment(.center)

                        Text(isForNoInternet ? "Couldn't connect to the network. \nPlease check and try again." : "This is all we know, but we won't stop until we fix the issue!")
                            .font(.subTitle1())
                            .tracking(-0.2)
                            .foregroundColor(disableText)
                            .multilineTextAlignment(.center)
                    }

                    VSpacer(40)

                    CapsuleButton(buttonName: "Retry", paddingHr: 73, paddingVr: 12, onClick: onClick)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: isIpad ? 600 : nil, minHeight: geometry.size.height - 100, maxHeight: .infinity, alignment: .center)
            }
            .frame(minWidth: geometry.size.width)
        }
    }
}
