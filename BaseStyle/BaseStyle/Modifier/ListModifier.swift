//
//  ListModifier.swift
//  BaseStyle
//
//  Created by Nirali Sonani on 07/06/24.
//

import SwiftUI

struct HideListIndicatorsViewModifier: ViewModifier {

    @ViewBuilder
    public func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
        } else {
            content
                .onAppear {
                    UITableView.appearance().showsVerticalScrollIndicator = false
                }
        }
    }
}

public extension View {
    func scrollIndicatorsHidden() -> some View {
        return self.modifier(HideListIndicatorsViewModifier())
    }
}
