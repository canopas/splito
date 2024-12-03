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
                            EmailFieldView(email: $viewModel.email, focusedField: $focusedField)

                            PasswordFieldView(password: $viewModel.password, focusedField: $focusedField,
                                              isPasswordVisible: viewModel.isPasswordVisible,
                                              handlePasswordEyeTap: viewModel.handlePasswordEyeTap,
                                              onEditingChanged: viewModel.onEditingChanged(abc:))

                            Spacer()

                            PrimaryButton(text: "Sign in", isEnabled: !viewModel.email.isEmpty && !viewModel.password.isEmpty,
                                          showLoader: viewModel.showLoader, onClick: viewModel.onEmailLoginClick)

                            Button("Forgot your password?") {}
                                .padding()
                                .underline()
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
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            BackButton(onClick: viewModel.handleBackBtnTap)
        }
    }
}

private struct EmailFieldView: View {

    @Binding var email: String
    var focusedField: FocusState<EmailLoginViewModel.EmailLoginField?>.Binding

    var body: some View {
        Text("Email address")
            .font(.subTitle1())
            .foregroundStyle(secondaryText)

        TextField("Your email address", text: $email)
            .autocapitalization(.none)
            .keyboardType(.emailAddress)
            .padding(16)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(outlineColor, lineWidth: 1)
            }
            .onSubmit {
                focusedField.wrappedValue = .password
            }
            .focused(focusedField, equals: .email)
            .submitLabel(.next)
            .padding(.top, 16)
    }
}

private struct PasswordFieldView: View {

    @Binding var password: String
    var focusedField: FocusState<EmailLoginViewModel.EmailLoginField?>.Binding

    let isPasswordVisible: Bool
    var handlePasswordEyeTap: () -> Void
    var onEditingChanged: (Bool) -> Void

    var body: some View {
        Text("Password")
            .font(.subTitle1())
            .foregroundStyle(secondaryText)

        HStack {
            if isPasswordVisible {
                TextField("Your password", text: $password, onEditingChanged: onEditingChanged)
            } else {
                SecureField("Your password", text: $password)
            }
        }
        .padding(16)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(outlineColor, lineWidth: 1)
        }
        .overlay(alignment: .trailing) {
            Image(systemName: isPasswordVisible  ? "eye.fill" : "eye.slash.fill")
                .font(.system(size: 14))
                .padding()
                .onTapGesture(perform: handlePasswordEyeTap)
        }
        .focused(focusedField, equals: .password) // Bind focus to password field
        .submitLabel(.done)
        .padding(.top, 16)
    }
}
