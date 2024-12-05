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

                            EmailFieldView(email: $viewModel.email, focusedField: $focusedField)

                            VSpacer(16)

                            PasswordFieldView(password: $viewModel.password, focusedField: $focusedField)
                            VSpacer(8)

                            HStack {
                                Spacer()

                                Button(action: viewModel.onForgotPasswordClick) {
                                    Text("Forgot password?")
                                        .font(.caption1())
                                        .foregroundStyle(disableText)
                                }
                            }

                            Spacer()

                            PrimaryButton(text: "Login", isEnabled: !viewModel.email.isEmpty && !viewModel.password.isEmpty,
                                          showLoader: viewModel.isLoginInProgress, onClick: viewModel.onEmailLoginClick)
                            .padding(.top, 8)

                            VSpacer(16)

                            PrimaryButton(text: "Create account", textColor: primaryDarkColor, bgColor: container2Color,
                                          showLoader: viewModel.isSignupInProgress, onClick: viewModel.onCreateAccountClick)

                            VSpacer(40)
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: isIpad ? 600 : nil, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(surfaceColor)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            BackButton(onClick: viewModel.handleBackBtnTap)
        }
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
    }
}

private struct EmailFieldView: View {

    @Binding var email: String
    var focusedField: FocusState<EmailLoginViewModel.EmailLoginField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Email")
                .font(.body3())
                .foregroundStyle(secondaryText)

            TextField("Enter your email", text: $email)
                .font(.subTitle3())
                .foregroundStyle(primaryText)
                .tint(primaryColor)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(outlineColor, lineWidth: 1)
                }
                .onSubmit {
                    focusedField.wrappedValue = .password
                }
                .focused(focusedField, equals: .email)
                .submitLabel(.next)
        }
    }
}

private struct PasswordFieldView: View {

    @Binding var password: String
    var focusedField: FocusState<EmailLoginViewModel.EmailLoginField?>.Binding

    @State private var isSecured: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password")
                .font(.body3())
                .foregroundStyle(secondaryText)

            ZStack(alignment: .trailing) {
                Group {
                    if isSecured {
                        SecureField("Enter your password", text: $password)
                    } else {
                        TextField("Enter your password", text: $password)
                    }
                }
                .font(.subTitle3())
                .foregroundStyle(primaryText)
                .tint(primaryColor)
                .autocapitalization(.none)
                .focused(focusedField, equals: .password)
                .submitLabel(.done)

                Button {
                    isSecured.toggle()
                } label: {
                    Image(systemName: self.isSecured ? "eye.slash" : "eye")
                        .accentColor(.gray)
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
