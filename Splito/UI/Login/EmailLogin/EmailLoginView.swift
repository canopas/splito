//
//  EmailLoginView.swift
//  Splito
//
//  Created by Nirali Sonani on 03/12/24.
//

import SwiftUI
import BaseStyle

struct EmailLoginView: View {

    @StateObject var viewModel: EmailLoginViewModel

    @FocusState private var focusedField: EmailLoginViewModel.EmailLoginField?

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        AppLogoView(geometry: .constant(proxy))

                        Group {
                            LoginTitleView(titleText: "Continue your journey")

                            VSpacer(16)

                            LoginSubtitleView(subtitleText: "Sign in to access your account and enjoy all its features.")

                            VSpacer(24)

                            EmailLoginInputFieldView(text: $viewModel.email, focusedField: $focusedField, title: "email") {
                                focusedField = .password
                            }

                            VSpacer(16)

                            EmailLoginInputFieldView(text: $viewModel.password, focusedField: $focusedField,
                                                     title: "password", isPasswordField: true)

                            ForgotPasswordView(onForgotPasswordClick: viewModel.onForgotPasswordClick)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: isIpad ? 600 : nil, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                VStack(spacing: 0) {
                    PrimaryFloatingButton(text: "Login", bottomPadding: 6,
                                          isEnabled: !viewModel.email.isEmpty && !viewModel.password.isEmpty,
                                          showLoader: viewModel.isLoginInProgress, onClick: viewModel.onLoginClick)

                    PrimaryFloatingButton(text: "Create account", textColor: primaryDarkColor, bgColor: container2Color,
                                          showLoader: viewModel.isSignupInProgress, onClick: viewModel.onCreateAccountClick)
                }
                .frame(maxWidth: isIpad ? 600 : nil, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .background(surfaceColor)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            BackButton(onClick: viewModel.navigateToRoot)
        }
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
    }
}

private struct EmailLoginInputFieldView: View {

    @Binding var text: String
    var focusedField: FocusState<EmailLoginViewModel.EmailLoginField?>.Binding

    let title: String
    var isPasswordField: Bool = false

    var onSubmit: (() -> Void)?

    @State private var isSecured: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.capitalized.localized)
                .font(.body3())
                .foregroundStyle(secondaryText)

            ZStack(alignment: .trailing) {
                Group {
                    if isPasswordField && isSecured {
                        SecureField("Enter your \(title.localized)", text: $text)
                    } else {
                        TextField("Enter your \(title.localized)", text: $text)
                            .keyboardType(isPasswordField ? .default : .emailAddress)
                    }
                }
                .font(.subTitle3())
                .foregroundStyle(primaryText)
                .tint(primaryColor)
                .autocapitalization(.none)
                .focused(focusedField, equals: isPasswordField ? .password : .email)
                .submitLabel(isPasswordField ? .done : .next)
                .onSubmit {
                    onSubmit?()
                }

                if isPasswordField {
                    Button {
                        isSecured.toggle()
                    } label: {
                        Image(systemName: isSecured ? "eye.slash" : "eye")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .foregroundStyle(lowestText)
                            .fontWeight(.bold)
                            .padding(3)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(outlineColor, lineWidth: 1)
            }
        }
    }
}

private struct ForgotPasswordView: View {

    let onForgotPasswordClick: () -> Void

    var body: some View {
        HStack {
            Spacer()

            Button(action: onForgotPasswordClick) {
                Text("Forgot password?")
                    .font(.caption1())
                    .foregroundStyle(disableText)
            }
        }
        .padding(.top, 8)
    }
}
