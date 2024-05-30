//
//  ShareSheetView.swift
//  BaseStyle
//
//  Created by Nirali Sonani on 30/05/24.
//

import Foundation
import UIKit

public func openShareSheet(items: [Any]) {
    DispatchQueue.main.async {
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        let rootVC = UIApplication.shared.currentUIWindow()?.rootViewController
        if let popVC = activityViewController.popoverPresentationController, let rootVC {
            popVC.sourceView = rootVC.view
            popVC.sourceRect = rootVC.view.bounds
            popVC.permittedArrowDirections = .init(rawValue: 0)
        }

        rootVC?.present(activityViewController, animated: true, completion: nil)
    }
}
