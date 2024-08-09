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

    public init(text: Binding<String>, isFocused: FocusState<Bool>.Binding, placeholder: String) {
        self._text = text
        self.isFocused = isFocused
        self.placeholder = placeholder
    }

    public func makeUIView(context: UIViewRepresentableContext<SearchBar>) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.placeholder = placeholder.localized
        searchBar.searchTextField.font = UIFont(name: "Lato", size: 16)
        searchBar.searchBarStyle = .minimal
        searchBar.setSearchFieldBackgroundImage(UIImage(), for: .normal)
        searchBar.searchTextField.textColor = UIColor(primaryText)
        searchBar.setImage(UIImage(named: "CloseIcon"), for: .clear, state: .normal)
        searchBar.searchTextPositionAdjustment = UIOffset(horizontal: 5.0, vertical: 0.0)
        return searchBar
    }

    public func updateUIView(_ uiView: UISearchBar, context: UIViewRepresentableContext<SearchBar>) {
        uiView.text = text.localized
    }

    public func makeCoordinator() -> SearchBar.Coordinator {
        return Coordinator(text: $text, isFocused: isFocused)
    }

    public class Coordinator: NSObject, UISearchBarDelegate {

        @Binding var text: String

        var isFocused: FocusState<Bool>.Binding

        public init(text: Binding<String>, isFocused: FocusState<Bool>.Binding) {
            self._text = text
            self.isFocused = isFocused
        }

        public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }
    }
}
