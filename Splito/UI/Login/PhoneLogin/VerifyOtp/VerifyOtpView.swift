//
//  VerifyOtpView.swift
//  Splito
//
//  Created by Amisha Italiya on 23/02/24.
//

import SwiftUI
import BaseStyle

public struct VerifyOtpView: View {
    @ObservedObject var viewModel: VerifyOtpViewModel

    @State var selectedField: Int = 0

    public init(viewModel: VerifyOtpViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            if case .loading = viewModel.currentState {
                LoaderView(tintColor: primaryColor, scaleSize: 2)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        VSpacer(50)

                        Text("Splito")
                            .font(.Header1(40))
                            .foregroundColor(primaryColor)

                        Spacer(minLength: 40)

                        SubtitleTextView(text: "Verification code", fontSize: .Header1(), fontColor: primaryText)

                        VSpacer(16)

                        VStack(spacing: 16) {
                            Text("We've sent a verification code to your phone")
                                .font(.subTitle2())
                                .foregroundColor(disableText)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)

                            HStack(alignment: .center, spacing: 8) {
                                Text(viewModel.phoneNumber)
                                    .font(.subTitle2())
                                    .foregroundColor(primaryText)

                                Button(action: viewModel.editButtonAction, label: {
                                    Image(.editPencil)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 24, height: 24, alignment: .center)
                                })
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
            }
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

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .center, spacing: 0) {

                CustomTextField(text: $otp, selectedField: $selectedField, placeholder: "Enter code", font: .inter(.medium, size: 34),
                                placeholderFont: .inter(.medium, size: 16), tag: 1, isDisabled: showLoader, keyboardType: .numberPad,
                                returnKey: .default, textAlignment: .center, characterLimit: 6, textContentType: .oneTimeCode)
                .frame(height: 45, alignment: .center)
                .background(Color.clear)

                Divider()
                    .background(outlineColor)
                    .padding(.horizontal, 60)
            }
            .onAppear {
                if otp.isEmpty {
                    selectedField = 1
                } else {
                    selectedField = 0
                    UIApplication.shared.endEditing()
                }
            }

            VSpacer(40)
            PrimaryButton(text: "Verify", showLoader: showLoader, onClick: onVerify)
            VSpacer(16)

            if resendOtpCount > 0 {
                HStack(spacing: 5) {
                    Text("Resend code")
                        .font(.subTitle2(14))
                        .foregroundColor(primaryColor)

                    Text("00:\(String(format: "%02d", resendOtpCount))")
                        .font(.subTitle2(14))
                        .foregroundColor(primaryText)
                }
                .lineSpacing(1)
            } else {
                Button(action: onResendOtp) {
                    Text("Resend code")
                        .font(.subTitle2(14))
                        .foregroundColor(primaryColor)
                        .padding(.horizontal, 10)
                        .lineSpacing(1)
                }
                .buttonStyle(.scale)
            }
        }
        .padding(.horizontal, 16)
        .onChange(of: otp) { _ in
            if otp.count == OTP_TOTAL_CHARACTERS {
                onVerify()
                UIApplication.shared.endEditing()
            }
        }
    }
}
