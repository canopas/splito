//
//  LoginView.swift
//  Splito
//
//  Created by Amisha Italiya on 16/02/24.
//

import BaseStyle
import SwiftUI

struct LoginView: View {

    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var viewModel: LoginViewModel

    public init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        if case .loading = viewModel.currentState {
            LoaderView(tintColor: primaryColor, scaleSize: 2)
        } else {
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .center, spacing: 0) {
                        VSpacer(20)

                        Image(.splito)
                            .resizable()
                            .frame(width: 160, height: 160, alignment: .center)

                        VSpacer(30)

                        Text("Sign up in the app to use amazing spliting features")
                            .font(.inter(.bold, size: 22).bold())
                            .foregroundColor(inverseSurfaceColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        VSpacer(30)

                        LoginOptionsView(onGoogleLoginClick: viewModel.onGoogleLoginClick, onAppleLoginClick: viewModel.onAppleLoginView, onPhoneLoginClick: viewModel.onPhoneLoginClick)

                        VSpacer(30)
                    }
                    .frame(minHeight: proxy.size.height - 80, alignment: .center)
                    .padding(.horizontal, 20)
                }
                .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
                .background(
                    LinearGradient(colors: colorScheme == .dark ? [surfaceDarkColor] :
                                    [primaryColor.opacity(0), primaryColor.opacity(0.16), primaryColor.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                )
            }
            .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        }
    }
}

private struct LoginOptionsView: View {

    @Environment(\.colorScheme) var colorScheme

    let onGoogleLoginClick: () -> Void
    let onAppleLoginClick: () -> Void
    let onPhoneLoginClick: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            LoginOptionsButtonView(image: .googleIcon, buttonName: "Sign in with Google", bgColor: surfaceLightColor, buttonTextColor: surfaceDarkColor, onClick: onGoogleLoginClick)
            LoginOptionsButtonView(image: .appleIcon, buttonName: "Sign in with Apple", bgColor: inverseSurfaceColor, buttonTextColor: backgroundColor, onClick: onAppleLoginClick)
            LoginOptionsButtonView(image: .phoneLoginIcon, buttonName: "Sign in with Phone Number", bgColor: primaryColor, onClick: onPhoneLoginClick)
        }
    }
}

private struct LoginOptionsButtonView: View {

    let image: ImageResource
    let buttonName: String
    let bgColor: Color
    let buttonTextColor: Color
    let onClick: () -> Void

    init(image: ImageResource, buttonName: String, bgColor: Color, buttonTextColor: Color = primaryDarkText, onClick: @escaping () -> Void) {
        self.image = image
        self.buttonName = buttonName
        self.bgColor = bgColor
        self.buttonTextColor = buttonTextColor
        self.onClick = onClick
    }

    public var body: some View {
        ZStack(alignment: .center) {
            Button(action: {
                onClick()
            }, label: {
                ZStack {
                    HStack(alignment: .center, spacing: 12) {
                        Image(image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)

                        Text(buttonName)
                            .lineLimit(1)
                            .font(.buttonText())
                            .foregroundColor(buttonTextColor)
                            .frame(height: 50)
                            .minimumScaleFactor(0.5)
                    }
                    .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .background(bgColor)
                .cornerRadius(50)
            })
            .buttonStyle(.scale)
        }
    }
}

#Preview {
    LoginView(viewModel: LoginViewModel())
}
