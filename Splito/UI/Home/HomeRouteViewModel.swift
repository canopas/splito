//
//  HomeRouteViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 06/06/24.
//

import SwiftUI
import Data
import Combine

class HomeRouteViewModel: ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var deepLinkManager: DeepLinkManager

    @Published var isTabBarVisible: Bool = true
    @Published var openProfileView: Bool = false
    @Published var openOnboardFlow: Bool = false

    @Published var selectedTab: Int = 0
    @Published var activityLogId: String?

    private var cancelable = Set<AnyCancellable>()

    init() {
        deepLinkObserver()
    }

    func deepLinkObserver() {
        deepLinkManager.$type.sink { [weak self] type in
            guard let self else { return }
            switch type {
            case .group:
                self.selectedTab = 0
            default:
                break
            }
        }
        .store(in: &cancelable)
    }

    func openProfileOrOnboardFlow() {
        if preference.user == nil {
            openOnboardFlow = true
        } else if preference.isVerifiedUser && (preference.user?.firstName == nil ||
                                                preference.user?.firstName == "") {
            openProfileView = true
        }
    }

    func setSelectedTab(_ index: Int) {
        selectedTab = index
    }

    func dismissProfileView() {
        openProfileView = false
    }

    func dismissOnboardFlow() {
        openOnboardFlow = false
    }

    func switchToActivityLog(activityId: String) {
        activityLogId = activityId
        selectedTab = 1
    }

    func handleDeepLink(url: URL) {
        deepLinkManager.handleDeepLink(url)
    }
}
