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

    @State var selectedField: Int = 0

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VSpacer(50)

                Text("Splito")
                    .font(.Header1(40))
                    .foregroundStyle(primaryColor)

                Spacer(minLength: 40)

                SubtitleTextView(text: "Verification code", fontSize: .Header1(), fontColor: primaryText)

                VSpacer(16)

                VStack(spacing: 16) {
                    Text("We've sent a verification code to your phone")
                        .font(.subTitle2())
                        .foregroundStyle(disableText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)

                    HStack(alignment: .center, spacing: 8) {
                        Text(viewModel.phoneNumber)
                            .font(.subTitle2())
                            .foregroundStyle(primaryText)

                        if viewModel.isFromPhoneLogin {
                            Button(action: viewModel.editButtonAction, label: {
                                Image(.editPencil)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 24, height: 24, alignment: .center)
                            })
                        }
                    }
                }
                .padding(.horizontal, 40)

                VSpacer(40)

                HStack(spacing: 0) {
                    Spacer()

                    PhoneLoginOtpView(otp: $viewModel.otp, resendOtpCount: $viewModel.resendOtpCount,
                                      selectedField: $selectedField, showLoader: viewModel.showLoader,
                                      onVerify: {
                        viewModel.verifyOTP()
                        selectedField = 0
                        UIApplication.shared.endEditing()
                    },
                                      onResendOtp: viewModel.resendOtp)
                    .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)

                    Spacer()
                }
                Spacer()
            }
        }
        .scrollIndicators(.hidden)
        .background(backgroundColor)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toastView(toast: $viewModel.toast)
        .onTapGesture {
            selectedField = 0
            UIApplication.shared.endEditing()
        }
        .onDisappear {
            viewModel.resendTimer?.invalidate()
        }
    }
}

private struct PhoneLoginOtpView: View {

    @Binding var otp: String
    @Binding var resendOtpCount: Int
    @Binding var selectedField: Int
    let showLoader: Bool

    let onVerify: () -> Void
    let onResendOtp: () -> Void

    private let OTP_TOTAL_CHARACTERS = 6
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            OtpTextInputView(text: $otp, isFocused: $isFocused, onOtpVerify: onVerify)
                .onAppear {
                    if otp.isEmpty {
                        isFocused = true
                    } else {
                        isFocused = false
                        UIApplication.shared.endEditing()
                    }
            }

            VSpacer(40)

            PrimaryButton(text: "Verify", isEnabled: !otp.isEmpty, showLoader: showLoader, onClick: onVerify)

            VSpacer(16)

            if resendOtpCount > 0 {
                HStack(spacing: 5) {
                    Text("Resend code")
                        .font(.subTitle2(14))
                        .foregroundStyle(primaryColor)

                    Text("00:\(String(format: "%02d", resendOtpCount))")
                        .font(.subTitle2(14))
                        .foregroundStyle(primaryText)
                }
                .lineSpacing(1)
            } else {
                Button(action: onResendOtp) {
                    Text("Resend code")
                        .font(.subTitle2(14))
                        .foregroundStyle(primaryColor)
                        .padding(.horizontal, 10)
                        .lineSpacing(1)
                }
                .buttonStyle(.scale)
            }
        }
        .padding(.horizontal, 16)
        .onChange(of: selectedField) { newValue in
            isFocused = (newValue == 1)
        }
    }
}

#Preview {
    VerifyOtpView(viewModel: VerifyOtpViewModel(router: .init(root: .VerifyOTPView(phoneNumber: "", verificationId: "")), phoneNumber: "", verificationId: ""))
}
