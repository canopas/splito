//
//  CustomTextField.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 23/02/24.
//

import SwiftUI

public struct CustomTextField: UIViewRepresentable {

    enum TextFieldType {
        case email
        case number
        case otp
        case reguler
    }

    public class CustomField: UITextField {
        var deleteHandler: (() -> Void)?

        override public func deleteBackward() {
            if text!.isEmpty {
                deleteHandler?()
            }
            super.deleteBackward()
        }
    }

    @Binding var text: String
    @Binding var selectedField: Int

    let placeholder: String
    var font: UIFont?
    var placeholderFont: UIFont?
    var color: UIColor = .black
    var tag: Int
    var isDisabled = false
    var keyboardType: UIKeyboardType = .asciiCapable
    var returnKey: UIReturnKeyType = .next
    var textAlignment: NSTextAlignment = .left
    var characterLimit: Int?
    var textContentType: UITextContentType?
    var onCommit: (() -> Void)?
    var onClear: (() -> Void)?

    public init(text: Binding<String>, selectedField: Binding<Int>, placeholder: String, font: UIFont? = nil, placeholderFont: UIFont? = nil, tag: Int, isDisabled: Bool = false, keyboardType: UIKeyboardType = .asciiCapable, returnKey: UIReturnKeyType = .next, textAlignment: NSTextAlignment = .left, characterLimit: Int? = nil, textContentType: UITextContentType? = nil, onCommit: (() -> Void)? = nil, onClear: (() -> Void)? = nil) {
        self._text = text
        self._selectedField = selectedField
        self.placeholder = placeholder
        self.font = font
        self.placeholderFont = placeholderFont
        self.tag = tag
        self.isDisabled = isDisabled
        self.keyboardType = keyboardType
        self.returnKey = returnKey
        self.textAlignment = textAlignment
        self.characterLimit = characterLimit
        self.textContentType = textContentType
        self.onCommit = onCommit
        self.onClear = onClear
    }

    public func makeUIView(context: UIViewRepresentableContext<CustomTextField>) -> CustomField {
        let textField = CustomField(frame: .zero)
        textField.delegate = context.coordinator
        textField.keyboardType = keyboardType
        textField.returnKeyType = returnKey
        textField.placeholder = placeholder.localized
        textField.tag = tag
        textField.textColor = UIColor(primaryText)
        textField.textAlignment = textAlignment
        textField.deleteHandler = onClear
        textField.isUserInteractionEnabled = !isDisabled
        textField.autocapitalizationType = .none
        textField.textContentType = textContentType ?? nil
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        if let textFont = font, let placeholderFont = placeholderFont {
            textField.font = textField.text!.isEmpty ? placeholderFont : textFont
        }
        return textField
    }

    public func makeCoordinator() -> CustomTextField.Coordinator {
        return Coordinator(text: $text, onCommit: onCommit, textContentType: textContentType, maxLength: characterLimit, textFont: font, placeholderFont: placeholderFont)
    }

    public func updateUIView(_ uiView: CustomField, context: UIViewRepresentableContext<CustomTextField>) {
        uiView.text = text
        context.coordinator.newSelection = { newSelection in
            DispatchQueue.main.async {
                self.selectedField = newSelection
            }
        }

        if textContentType == .oneTimeCode {
            if !uiView.text!.isEmpty {
                let attributedString = NSMutableAttributedString(string: uiView.text!)
                attributedString.addAttribute(NSAttributedString.Key.kern, value: uiView.frame.width / 25, range: NSRange(location: 0, length: attributedString.length - 1))
                uiView.attributedText = attributedString
            }
        }

        if uiView.tag == self.selectedField {
            uiView.becomeFirstResponder()
        }
    }

    public class Coordinator: NSObject, UITextFieldDelegate {

        @Binding var text: String

        var onCommit: (() -> Void)?
        var newSelection: (Int) -> Void = { _ in }
        let textContentType: UITextContentType?
        let maxLength: Int?
        let textFont: UIFont?
        let placeholderFont: UIFont?

        public init(text: Binding<String>, onCommit: (() -> Void)? = nil, textContentType: UITextContentType?, maxLength: Int?, textFont: UIFont?, placeholderFont: UIFont?) {
            _text = text
            self.onCommit = onCommit
            self.textContentType = textContentType
            self.maxLength = maxLength
            self.textFont = textFont
            self.placeholderFont = placeholderFont
        }

        public func textFieldDidChangeSelection(_ textField: UITextField) {
            DispatchQueue.main.async {
                self.text = textField.text ?? ""
                if let textFont = self.textFont, let placeholderFont = self.placeholderFont {
                    textField.font = textField.text!.isEmpty ? placeholderFont : textFont
                }
            }
        }

        public func textFieldDidBeginEditing(_ textField: UITextField) {
            self.newSelection(textField.tag)
        }

        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if textField.returnKeyType == .done {
                textField.resignFirstResponder()
            } else {
                self.newSelection(textField.tag + 1)
            }
            return true
        }

        public func textFieldDidEndEditing(_ textField: UITextField) {
            onCommit?()
        }

        public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if textContentType == .oneTimeCode {
                let aSet = NSCharacterSet(charactersIn: "0123456789").inverted
                let compSepByCharInSet = string.components(separatedBy: aSet)
                let numberFiltered = compSepByCharInSet.joined(separator: "")
                if string == numberFiltered, let maxLength = maxLength {
                    let maxLength = maxLength
                    let currentString: NSString = textField.text! as NSString
                    let newString: NSString =
                    currentString.replacingCharacters(in: range, with: string) as NSString
                    return newString.length <= maxLength
                }
                return true
            } else {
                return true
            }
        }
    }
}
