//
//  ErrorView.swift
//  Splito
//
//  Created by Nirali Sonani on 23/09/24.
//

import SwiftUI
import BaseStyle

public struct ErrorView: View {

    let isForNoInternet: Bool

    let onClick: (() -> Void)?

    public init(isForNoInternet: Bool, onClick: (() -> Void)?) {
        self.isForNoInternet = isForNoInternet
        self.onClick = onClick
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Image(isForNoInternet ? .noInternetIcon : .somethingWentWrong)

                    VSpacer(40)

                    VStack(spacing: 16) {
                        Text(isForNoInternet ? "No internet!" :  "Something went wrong!")
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
                .frame(maxWidth: isIpad ? 600 : nil, minHeight: geometry.size.height - 100, maxHeight: .infinity, alignment: .center)
            }
            .frame(minWidth: geometry.size.width)
        }
    }
}

public struct CapsuleButton: View {

    @StateObject private var loaderModel: LoaderViewModel = .init()

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
            .background(surfaceColor)
            .cornerRadius(12)
        }
        .buttonStyle(.scale)
        .disabled(!isEnabled)
    }
}
