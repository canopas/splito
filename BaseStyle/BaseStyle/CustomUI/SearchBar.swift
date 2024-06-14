//
//  SearchBar.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 23/02/24.
//

import SwiftUI

public struct SearchBar: UIViewRepresentable {

    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    let placeholder: String
    let clearButtonMode: UITextField.ViewMode
    let showCancelButton: Bool
    let onCancel: (() -> Void)?

    public init(text: Binding<String>, isFocused: FocusState<Bool>.Binding, placeholder: String, showCancelButton: Bool = false, clearButtonMode: UITextField.ViewMode = .whileEditing, onCancel: (() -> Void)? = nil) {
        self._text = text
        self.isFocused = isFocused
        self.placeholder = placeholder
        self.showCancelButton = showCancelButton
        self.clearButtonMode = clearButtonMode
        self.onCancel = onCancel
    }

    public func makeUIView(context: UIViewRepresentableContext<SearchBar>) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.placeholder = placeholder
        searchBar.searchBarStyle = .minimal
        searchBar.showsCancelButton = showCancelButton
        searchBar.searchTextField.clearButtonMode = clearButtonMode
        return searchBar
    }

    public func updateUIView(_ uiView: UISearchBar, context: UIViewRepresentableContext<SearchBar>) {
        uiView.text = text.localized
    }

    public func makeCoordinator() -> SearchBar.Coordinator {
        return Coordinator(text: $text, isFocused: isFocused, onCancel: onCancel)
    }

    public class Coordinator: NSObject, UISearchBarDelegate {

        @Binding var text: String

        var isFocused: FocusState<Bool>.Binding
        let onCancel: (() -> Void)?

        public init(text: Binding<String>, isFocused: FocusState<Bool>.Binding, onCancel: (() -> Void)?) {
            self._text = text
            self.isFocused = isFocused
            self.onCancel = onCancel
        }

        public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }

        public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            if !text.isEmpty {
                text = ""
                isFocused.wrappedValue = true
            } else {
                onCancel?()
            }
        }
    }
}
