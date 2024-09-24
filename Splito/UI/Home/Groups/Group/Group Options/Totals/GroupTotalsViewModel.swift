//
//  GroupTotalsViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import Data
import SwiftUI

class GroupTotalsViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository

    @Published private(set) var viewState: ViewState = .initial
    @Published private(set) var selectedTab: DateRangeTabType = .thisMonth
    @Published private(set) var summaryData: GroupMemberSummary?

    private var group: Groups?
    private let groupId: String

    init(groupId: String) {
        self.groupId = groupId
        super.init()
        fetchInitialGroupData()
    }

    func fetchInitialGroupData() {
        Task {
            await fetchGroup()
        }
    }

    // MARK: - Data Loading
    private func fetchGroup() async {
        do {
            viewState = .loading
            let latestGroup = try await groupRepository.fetchGroupBy(id: groupId)
            group = latestGroup
            filterDataForSelectedTab()
            viewState = .initial
        } catch {
            handleServiceError()
        }
    }

    // MARK: - User Actions
    func handleTabItemSelection(_ selection: DateRangeTabType) {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTab = selection
            filterDataForSelectedTab()
        }
    }

    private func filterDataForSelectedTab() {
        guard let group, let userId = preference.user?.id else { return }

        let summaries: [GroupTotalSummary]
        switch selectedTab {
        case .thisMonth:
            summaries = getTotalSummaryForCurrentMonth(group: group, userId: userId)
        case .thisYear:
            summaries = getTotalSummaryForCurrentYear()
        case .all:
            summaries = group.balances.first(where: { $0.id == userId })?.totalSummary ?? []
        }

        summaryData = GroupMemberSummary(
            groupTotalSpending: summaries.reduce(0) { $0 + $1.summary.groupTotalSpending },
            totalPaidAmount: summaries.reduce(0) { $0 + $1.summary.totalPaidAmount },
            totalShare: summaries.reduce(0) { $0 + $1.summary.totalShare },
            paidAmount: summaries.reduce(0) { $0 + $1.summary.paidAmount },
            receivedAmount: summaries.reduce(0) { $0 + $1.summary.receivedAmount },
            changeInBalance: summaries.reduce(0) { $0 + $1.summary.changeInBalance }
        )
    }

    private func getTotalSummaryForCurrentYear() -> [GroupTotalSummary] {
        guard let user = preference.user, let group else { return [] }
        let currentYear = Calendar.current.component(.year, from: Date())
        return group.balances.first(where: { $0.id == user.id })?.totalSummary.filter {
            $0.year == currentYear
        } ?? []
    }

    // MARK: - Error Handling
    private func handleServiceError() {
        if !networkMonitor.isConnected {
            viewState = .noInternet
        } else {
            viewState = .somethingWentWrong
        }
    }
}

// MARK: - View States
extension GroupTotalsViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }
}

// MARK: - Tab Types
enum DateRangeTabType: Int, CaseIterable {

    case thisMonth, thisYear, all

    var tabItem: String {
        switch self {
        case .thisMonth:
            return "This month"
        case .thisYear:
            return "This year"
        case .all:
            return "All"
        }
    }
}
