//
//  UITabView.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 22/05/24.
//

import UIKit
import SwiftUI

public struct UITabView: View {
    private let viewControllers: [UIHostingController<AnyView>]
    private let tabBarItems: [TabBarItem]
    @Binding private var selectedIndex: Int

    public init(selection: Binding<Int>, @TabBuilder _ content: () -> [TabBarItem]) {
        _selectedIndex = selection

        (viewControllers, tabBarItems) = content().reduce(into: ([], [])) { result, next in
            let tabController = UIHostingController(rootView: next.view)
            tabController.tabBarItem = next.barItem
            result.0.append(tabController)
            result.1.append(next)
        }
    }

    public var body: some View {
        TabBarController(controllers: viewControllers, tabBarItems: tabBarItems, selectedIndex: $selectedIndex)
            .ignoresSafeArea()
            .toolbar(.hidden, for: .navigationBar)
    }
}

extension UITabView {
    public struct TabBarItem {
        let view: AnyView
        let barItem: UITabBarItem
        let badgeValue: String?

        init<T>(title: String, image: UIImage?, selectedImage: UIImage? = nil, badgeValue: String? = nil, content: T) where T: View {
            self.view = AnyView(content)
            self.barItem = UITabBarItem(title: title, image: image, selectedImage: selectedImage)
            self.badgeValue = badgeValue
        }
    }

    struct TabBarController: UIViewControllerRepresentable {
        let controllers: [UIViewController]
        let tabBarItems: [TabBarItem]
        @Binding var selectedIndex: Int

        func makeUIViewController(context: Context) -> UITabBarController {
            let tabBarController = UITabBarController()
            tabBarController.viewControllers = controllers
            tabBarController.delegate = context.coordinator
            tabBarController.selectedIndex = selectedIndex
            tabBarController.navigationController?.isNavigationBarHidden = true
            return tabBarController
        }

        func updateUIViewController(_ tabBarController: UITabBarController, context: Context) {
            tabBarController.selectedIndex = selectedIndex

            tabBarItems.forEach { tab in
                guard let index = tabBarItems.firstIndex(where: { $0.barItem == tab.barItem }),
                      let controllers = tabBarController.viewControllers
                else { return }

                guard controllers.indices.contains(index) else { return }
                controllers[index].tabBarItem.badgeValue = tab.badgeValue
            }
        }

        func makeCoordinator() -> TabBarCoordinator {
            TabBarCoordinator(self)
        }
    }

    class TabBarCoordinator: NSObject, UITabBarControllerDelegate {
        private static let inlineTitleRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        private var parent: TabBarController

        init(_ tabBarController: TabBarController) {
            self.parent = tabBarController
        }

        func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            guard parent.selectedIndex == tabBarController.selectedIndex else {
                parent.selectedIndex = tabBarController.selectedIndex
                return
            }

            guard let navigationController = navigationController(in: viewController) else { return }

            guard navigationController.visibleViewController == navigationController.viewControllers.first else {
                navigationController.popToRootViewController(animated: true)
                return
            }

            scrollToTop(in: navigationController)
        }

        func scrollToTop(in navigationController: UINavigationController) {
            let rootViewController = navigationController.viewControllers.first ?? navigationController

            guard let scrollView = firstScrollView(in: rootViewController.view) else { return }

            scrollView.scrollRectToVisible(Self.inlineTitleRect, animated: true)
        }

        func scrollView(in views: [UIView]) -> UIScrollView? {
            var view: UIScrollView?

            views.forEach {
                guard let scrollView = $0 as? UIScrollView else {
                    view = scrollView(in: $0.subviews)
                    return
                }
                view = scrollView
            }

            return view
        }

        public func firstScrollView(in view: UIView) -> UIScrollView? {
            for subview in view.subviews {
                if let scrollView = view as? UIScrollView {
                    return scrollView
                } else if let scrollView = firstScrollView(in: subview) {
                    return scrollView
                }
            }
            return nil
        }

        func navigationController(in viewController: UIViewController) -> UINavigationController? {
            var controller: UINavigationController?

            if let navigationController = viewController as? UINavigationController {
                return navigationController
            }

            viewController.children.forEach {
                guard let navigationController = $0 as? UINavigationController else {
                    controller = navigationController(in: $0)
                    return
                }
                controller = navigationController
            }

            return controller
        }
    }
}

extension View {
    public func tabItem(_ title: String, image: UIImage?, selectedImage: UIImage? = nil, badgeValue: String? = nil) -> UITabView.TabBarItem {
        UITabView.TabBarItem(title: title, image: image, selectedImage: selectedImage,
                             badgeValue: badgeValue, content: self)
    }
}

@resultBuilder
public struct TabBuilder {
    public static func buildBlock(_ elements: UITabView.TabBarItem...) -> [UITabView.TabBarItem] {
        elements
    }
}
