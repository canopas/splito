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

    let placeholder: String
    let isFocused: FocusState<Bool>.Binding
    let keyboardType: UIKeyboardType
    let alignment: TextAlignment

    var onOtpVerify: (() -> Void)?

    public init(text: Binding<String>, placeholder: String = "", isFocused: FocusState<Bool>.Binding,
                keyboardType: UIKeyboardType = .numberPad, alignment: TextAlignment = .center,
                onOtpVerify: ( () -> Void)? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.isFocused = isFocused
        self.keyboardType = keyboardType
        self.alignment = alignment
        self.onOtpVerify = onOtpVerify
    }

    public var body: some View {
        TextField(placeholder.localized, text: $text)
            .kerning(16)
            .focused(isFocused)
            .tint(primaryColor)
            .font(.Header2())
            .keyboardType(keyboardType)
            .foregroundStyle(primaryText)
            .multilineTextAlignment(alignment)
            .textContentType(.oneTimeCode)
            .autocorrectionDisabled()
            .onChange(of: text) { newValue in
                if newValue.count == OTP_TOTAL_CHARACTERS {
                    onOtpVerify?()
                    UIApplication.shared.endEditing()
                }
            }
            .textInputAutocapitalization(.never)
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
