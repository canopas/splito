//
//  VerifyOtpView.swift
//  Splito
//
//  Created by Amisha Italiya on 23/02/24.
//

import SwiftUI
import BaseStyle

public struct VerifyOtpView: View {

    @StateObject var viewModel: VerifyOtpViewModel

    public var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        AppLogoView(geometry: .constant(proxy))

                        Group {
                            LoginTitleView(titleText: "Verification code")

                            VSpacer(16)

                            LoginSubtitleView(subtitleText: "We’ve sent a verification code to your phone \(viewModel.hiddenPhoneNumber).")

                            VSpacer(40)

                            HStack {
                                OtpTextFieldView(otp: $viewModel.otp, onVerify: {
                                    viewModel.verifyOTP()
                                    UIApplication.shared.endEditing()
                                })

                                Spacer()
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: isIpad ? 600 : nil, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                PhoneLoginOtpBtnView(
                    otp: $viewModel.otp,
                    resendOtpCount: $viewModel.resendOtpCount,
                    showLoader: viewModel.showLoader,
                    onVerify: {
                        viewModel.verifyOTP()
                        UIApplication.shared.endEditing()
                    },
                    onResendOtp: viewModel.resendOtp
                )
            }
        }
        .background(surfaceColor)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toastView(toast: $viewModel.toast)
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
        .onDisappear {
            viewModel.resendTimer?.invalidate()
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            BackButton(onClick: viewModel.handleBackBtnTap)
        }
    }
}

private struct PhoneLoginOtpBtnView: View {

    @Binding var otp: String
    @Binding var resendOtpCount: Int
    let showLoader: Bool

    let onVerify: () -> Void
    let onResendOtp: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if resendOtpCount > 0 {
                Group {
                    Text("Resend code ")
                        .foregroundColor(secondaryText)
                    + Text("00:\(String(format: "%02d", resendOtpCount))")
                        .foregroundColor(primaryText)
                }
                .font(.caption1())
            } else {
                VStack(spacing: 0) {
                    Button(action: onResendOtp) {
                        Text("Resend code")
                            .font(.buttonText())
                            .foregroundStyle(primaryColor)
                    }

                    Divider()
                        .frame(height: 1)
                        .background(primaryColor)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            VSpacer(12)

            PrimaryButton(text: "Verify", isEnabled: !otp.isEmpty, showLoader: showLoader, onClick: onVerify)

            VSpacer(24)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct OtpTextFieldView: View {

    @Binding var otp: String

    let onVerify: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text("6 digits")
                .font(.subTitle1())
                .foregroundStyle(primaryText)
                .tracking(-0.2)

            Divider()
                .frame(height: 50)
                .background(dividerColor)
                .padding(.horizontal, 16)

            OtpTextInputView(text: $otp, placeholder: "000000", isFocused: $isFocused, alignment: .leading, onOtpVerify: onVerify)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
