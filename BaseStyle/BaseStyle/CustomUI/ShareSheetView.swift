//
//  ShareSheetView.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 12/03/24.
//

import SwiftUI

public struct ShareSheetView: UIViewControllerRepresentable {

    let activityItems: [Any]
    var onCompletion: ((Bool) -> Void)?

    public init(activityItems: [Any], onCompletion: ((Bool) -> Void)? = nil) {
        self.activityItems = activityItems
        self.onCompletion = onCompletion
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            self.onCompletion?(completed)
        }
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // nothing to do here
    }
}
