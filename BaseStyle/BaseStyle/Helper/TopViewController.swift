//
//  TopViewController.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 22/02/24.
//

import UIKit

public class TopViewController {

    static public let shared = TopViewController()

    public func topViewController(controller: UIViewController? = nil) -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }
        guard let controller = controller ?? windowScene.windows.first?.rootViewController else { return nil }

        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
}
