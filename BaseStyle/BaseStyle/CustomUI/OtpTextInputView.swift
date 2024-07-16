//
//  OtpTextInputView.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 20/06/24.
//

import SwiftUI

public struct OtpTextInputView: View {

    private let OTP_TOTAL_CHARACTERS = 6

    @Binding var text: String

    var isFocused: FocusState<Bool>.Binding
    var keyboardType: UIKeyboardType

    var onOtpVerify: (() -> Void)?

    public init(text: Binding<String>, isFocused: FocusState<Bool>.Binding,
                keyboardType: UIKeyboardType = .numberPad, onOtpVerify: ( () -> Void)? = nil) {
        self._text = text
        self.isFocused = isFocused
        self.keyboardType = keyboardType
        self.onOtpVerify = onOtpVerify
    }

    public var body: some View {
        VStack(alignment: .center, spacing: 10) {
            TextField("", text: $text)
                .kerning(16)
                .tint(primaryColor)
                .font(.subTitle1(34))
                .foregroundColor(primaryText)
                .multilineTextAlignment(.center)
                .keyboardType(keyboardType)
                .textContentType(.oneTimeCode)
                .disableAutocorrection(true)
                .focused(isFocused)
                .onChange(of: text) { newValue in
                    if newValue.count == OTP_TOTAL_CHARACTERS {
                        onOtpVerify?()
                        UIApplication.shared.endEditing()
                    }
                }
                .autocapitalization(.none)

            Divider()
                .background(outlineColor)
                .padding(.horizontal, 60)
        }
        .onAppear {
            if text.isEmpty {
                isFocused.wrappedValue = true
            } else {
                isFocused.wrappedValue = false
                UIApplication.shared.endEditing()
            }
        }
    }
}
