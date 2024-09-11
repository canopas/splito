//
//  LoginView.swift
//  Splito
//
//  Created by Amisha Italiya on 16/02/24.
//

import BaseStyle
import SwiftUI

struct LoginView: View {

    @StateObject var viewModel: LoginViewModel

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        AppLogoView(geometry: .constant(proxy))

                        Group {
                            Text("Getting started with us")
                                .font(.Header1())
                                .foregroundStyle(primaryText)

                            VSpacer(16)

                            Text("Sign up in the app to use amazing splitting features.")
                                .font(.subTitle1())
                                .foregroundStyle(disableText)
                                .tracking(-0.2)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: isIpad ? 600 : nil, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)

                        Spacer()
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                LoginOptionsView(showGoogleLoading: viewModel.showGoogleLoading,
                                 showAppleLoading: viewModel.showAppleLoading,
                                 onGoogleLoginClick: viewModel.onGoogleLoginClick,
                                 onAppleLoginClick: viewModel.onAppleLoginClick,
                                 onPhoneLoginClick: viewModel.onPhoneLoginClick)

                VSpacer(24)
            }
        }
        .background(surfaceColor)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct LoginOptionsView: View {

    let showGoogleLoading: Bool
    let showAppleLoading: Bool

    let onGoogleLoginClick: () -> Void
    let onAppleLoginClick: () -> Void
    let onPhoneLoginClick: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            LoginOptionsButtonView(image: .googleIcon, buttonName: "Sign in with Google", showLoader: showGoogleLoading, onClick: onGoogleLoginClick)
            LoginOptionsButtonView(systemImage: ("apple.logo", primaryText, (14, 16)), buttonName: "Sign in with Apple", showLoader: showAppleLoading, onClick: onAppleLoginClick)
            LoginOptionsButtonView(systemImage: ("phone.fill", primaryLightText, (12, 12)), buttonName: "Sign in with Phone Number", bgColor: primaryColor, buttonTextColor: primaryLightText, showLoader: false, onClick: onPhoneLoginClick)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct LoginOptionsButtonView: View {

    let image: ImageResource?
    let systemImage: (name: String, color: Color, size: (width: CGFloat, height: CGFloat))?
    let buttonName: String
    var bgColor: Color
    var buttonTextColor: Color
    let showLoader: Bool
    let onClick: () -> Void

    init(image: ImageResource? = nil, systemImage: (name: String, color: Color, size: (width: CGFloat, height: CGFloat))? = nil, buttonName: String, bgColor: Color = container2Color, buttonTextColor: Color = primaryDarkColor, showLoader: Bool, onClick: @escaping () -> Void) {
        self.image = image
        self.systemImage = systemImage
        self.buttonName = buttonName
        self.bgColor = bgColor
        self.buttonTextColor = buttonTextColor
        self.showLoader = showLoader
        self.onClick = onClick
    }

    public var body: some View {
        Button {
            onClick()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                if showLoader {
                    ImageLoaderView(tintColor: primaryColor)
                }

                if let image {
                    Image(image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                } else if let systemImage {
                    Image(systemName: systemImage.name)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: systemImage.size.width, height: systemImage.size.height)
                        .foregroundStyle(systemImage.color)
                }

                Text(buttonName.localized)
                    .lineLimit(1)
                    .font(.buttonText())
                    .foregroundStyle(buttonTextColor)
                    .frame(height: 44)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(bgColor)
            .cornerRadius(12)
        }
        .buttonStyle(.scale)
    }
}

struct AppLogoView: View {

    @Environment(\.colorScheme) var colorScheme

    @Binding var geometry: GeometryProxy

    private var width: CGFloat {
        (isIpad ? (geometry.size.width > 600 ? 600 : geometry.size.width) : geometry.size.width)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Spacer()

            Image(.loginAppLogo)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.2 + 200, height: geometry.size.height * 0.1 + 120, alignment: .center)
                .padding(.top, 88)
                .padding(.bottom, 40)

            Spacer()
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(colorScheme == .dark ? containerColor : primaryDarkColor)
        .padding(.bottom, 24)
    }
}
