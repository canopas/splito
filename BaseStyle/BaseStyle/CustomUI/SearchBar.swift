//
//  SearchBar.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 23/02/24.
//

import SwiftUI

public struct SearchBar: UIViewRepresentable {

    @Binding var text: String
    @Binding var isFocused: Bool

    let placeholder: String
    let showCancelButton: Bool
    let clearButtonMode: UITextField.ViewMode
    let onCancel: (() -> Void)?

    public init(text: Binding<String>, isFocused: Binding<Bool> = .constant(false), placeholder: String, showCancelButton: Bool = false, clearButtonMode: UITextField.ViewMode = .whileEditing, onCancel: (() -> Void)? = nil) {
        self._text = text
        self._isFocused = isFocused
        self.placeholder = placeholder
        self.clearButtonMode = clearButtonMode
        self.showCancelButton = showCancelButton
        self.onCancel = onCancel
    }

    public func makeUIView(context: UIViewRepresentableContext<SearchBar>) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.placeholder = placeholder
        searchBar.autocapitalizationType = .none
        searchBar.searchBarStyle = .minimal
        searchBar.searchTextField.clearButtonMode = clearButtonMode
        searchBar.showsCancelButton = showCancelButton
        return searchBar
    }

    public func updateUIView(_ uiView: UISearchBar, context: UIViewRepresentableContext<SearchBar>) {
        uiView.text = text

        if isFocused && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    public func makeCoordinator() -> SearchBar.Coordinator {
        return Coordinator(text: $text, isFocused: $isFocused, onCancel: onCancel, showCancelButton: showCancelButton)
    }

    public class Coordinator: NSObject, UISearchBarDelegate {

        @Binding var text: String
        @Binding var isFocused: Bool

        let onCancel: (() -> Void)?
        let showCancelButton: Bool

        public init(text: Binding<String>, isFocused: Binding<Bool>, onCancel: (() -> Void)?, showCancelButton: Bool) {
            _text = text
            _isFocused = isFocused
            self.onCancel = onCancel
            self.showCancelButton = showCancelButton
        }

        public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }

        public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            isFocused = true
            searchBar.setShowsCancelButton(showCancelButton, animated: true)
        }

        public func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            isFocused = false
            searchBar.setShowsCancelButton(showCancelButton, animated: true)
        }

        public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            if !text.isEmpty {
                text = ""
            } else {
                onCancel?()
            }
            isFocused = true
        }
    }
}
