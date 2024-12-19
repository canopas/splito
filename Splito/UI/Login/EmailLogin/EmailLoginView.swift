//
//  EmailLoginView.swift
//  Splito
//
//  Created by Amisha Italiya on 03/12/24.
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

                            EmailInputFieldView(email: $viewModel.email, focusedField: $focusedField)

                            VSpacer(16)

                            PasswordInputFieldView(password: $viewModel.password, focusedField: $focusedField)

                            ForgotPasswordView(onForgotPasswordClick: viewModel.onForgotPasswordClick)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: isIpad ? 600 : nil, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)

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
                    .frame(minHeight: proxy.size.height, maxHeight: .infinity, alignment: .center)
                    .ignoresSafeArea(.keyboard)
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
            BackButton(onClick: viewModel.navigateToRoot)
        }
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
        .onAppear {
            focusedField = .email
        }
    }
}

private struct EmailInputFieldView: View {

    @Binding var email: String
    var focusedField: FocusState<EmailLoginViewModel.EmailLoginField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Email")
                .font(.body3())
                .foregroundStyle(secondaryText)

            TextField("Enter your email", text: $email)
                .keyboardType(.emailAddress)
                .font(.subTitle3())
                .foregroundStyle(primaryText)
                .tint(primaryColor)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused(focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit {
                    focusedField.wrappedValue = .password
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

private struct PasswordInputFieldView: View {

    @Binding var password: String
    var focusedField: FocusState<EmailLoginViewModel.EmailLoginField?>.Binding

    @State private var isSecured = true
    @State private var visibleInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password")
                .font(.body3())
                .foregroundStyle(secondaryText)

            ZStack(alignment: .trailing) {
                TextField("Enter your password", text: $visibleInput)
                    .onChange(of: visibleInput) { newValue in
                        guard isSecured else { password = newValue; return }
                        if newValue.count >= password.count {
                            let newItem = newValue.filter { $0 != Character("•") }
                            password.append(newItem)
                        } else {
                            password.removeLast()
                        }
                        visibleInput = String(newValue.map { _ in Character("•") })
                    }
                    .font(.subTitle3())
                    .foregroundStyle(primaryText)
                    .tint(primaryColor)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)

                Image(systemName: isSecured ? "eye" : "eye.slash")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .foregroundStyle(lowestText)
                    .fontWeight(.black)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 19)
                    .onTapGestureForced {
                        isSecured.toggle()
                        visibleInput = isSecured ? String(password.map { _ in Character("•") }) : password
                    }
            }
            .focused(focusedField, equals: .password)
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
        .padding(.bottom, 24)
    }
}
