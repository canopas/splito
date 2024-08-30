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
    @Published private(set) var selectedTab: GroupTotalsTabType = .thisMonth
    @Published private(set) var summaryData: GroupMemberSummary?

    private var group: Groups?
    private let groupId: String

    init(groupId: String) {
        self.groupId = groupId
        super.init()
        fetchGroup()
    }

    // MARK: - Data Loading
    private func fetchGroup() {
        viewState = .loading
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] group in
                guard let self else { return }
                self.group = group
                self.filterDataForSelectedTab()
                self.viewState = .initial
            }.store(in: &cancelable)
    }

    // MARK: - User Actions
    func handleTabItemSelection(_ selection: GroupTotalsTabType) {
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
            summaries = getTotalSummaryForCurrentMonth()
        case .thisYear:
            summaries = getTotalSummaryForCurrentYear()
        case .all:
            summaries = group.balances.first(where: { $0.id == userId })?.totalSummary ?? []
        }

        summaryData = GroupMemberSummary(
            groupTotalSpending: summaries.reduce(0) { $0 + $1.summary.groupTotalSpending },
            totalPaidAmount: summaries.reduce(0) { $0 + $1.summary.totalPaidAmount },
            totalShare: summaries.reduce(0) { $0 + $1.summary.totalShare },
            paidAmount: getPaymentsMade(),
            receivedAmount: getPaymentsReceived(),
            changeInBalance: summaries.reduce(0) { $0 + $1.summary.changeInBalance }
        )
    }

    private func getTotalSummaryForCurrentMonth() -> [GroupTotalSummary] {
        guard let user = preference.user, let group else { return [] }

        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())

        return group.balances.first(where: { $0.id == user.id })?.totalSummary.filter {
            $0.month == currentMonth && $0.year == currentYear
        } ?? []
    }

    private func getTotalSummaryForCurrentYear() -> [GroupTotalSummary] {
        guard let user = preference.user, let group else { return [] }
        let currentYear = Calendar.current.component(.year, from: Date())

        return group.balances.first(where: { $0.id == user.id })?.totalSummary.filter {
            $0.year == currentYear
        } ?? []
    }

    private func getPaymentsMade() -> Double {
        guard let user = preference.user, let group else { return 0 }
        return group.balances.first(where: { $0.id == user.id })?.totalSummary.reduce(0) { $0 + $1.summary.paidAmount } ?? 0
    }

    private func getPaymentsReceived() -> Double {
        guard let user = preference.user, let group else { return 0 }
        return group.balances.first(where: { $0.id == user.id })?.totalSummary.reduce(0) { $0 + $1.summary.receivedAmount } ?? 0
    }

    // MARK: - Error Handling
    private func handleServiceError(_ error: ServiceError) {
        viewState = .initial
        showToastFor(error)
    }
}

// MARK: - View States
extension GroupTotalsViewModel {
    enum ViewState {
        case initial
        case loading
    }
}

// MARK: - Tab Types
enum GroupTotalsTabType: Int, CaseIterable {

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
