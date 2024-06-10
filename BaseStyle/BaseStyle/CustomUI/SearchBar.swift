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

    var placeholder: String

    public init(text: Binding<String>, placeholder: String, isFocused: Binding<Bool> = .constant(false)) {
        self._text = text
        self._isFocused = isFocused
        self.placeholder = placeholder
    }

    public func makeUIView(context: UIViewRepresentableContext<SearchBar>) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.placeholder = placeholder
        searchBar.autocapitalizationType = .none
        searchBar.searchBarStyle = .minimal
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
        return Coordinator(text: $text, isFocused: $isFocused)
    }

    public class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String
        @Binding var isFocused: Bool

        public init(text: Binding<String>, isFocused: Binding<Bool>) {
            _text = text
            _isFocused = isFocused
        }

        public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }

        public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            isFocused = true
        }

        public func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            isFocused = false
        }
    }
}
