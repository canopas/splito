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

    @Published private(set) var viewState: ViewState = .loading
    @Published private(set) var selectedTab: DateRangeTabType = .thisMonth
    @Published private(set) var summaryData: GroupMemberSummary?

    @Published var showCurrencyPicker = false
    @Published var supportedCurrency: [String] = [Currency.defaultCurrency.code]
    @Published var selectedCurrency: Currency = Currency.getCurrentLocalCurrency() {
        didSet {
            filterDataForSelectedTab()  // Recalculate data when currency changes
        }
    }

    var group: Groups?
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
            group = try await groupRepository.fetchGroupBy(id: groupId)

            // Extract supported currencies from group data
            if let userId = preference.user?.id,
               let balanceByCurrency = group?.balances.first(where: { $0.id == userId })?.balanceByCurrency {
                let currencies = Set(balanceByCurrency.keys) // Extract all unique currency
                supportedCurrency = Array(currencies)
            }

            filterDataForSelectedTab()
            viewState = .initial
            LogD("GroupTotalsViewModel: \(#function) Group fetched successfully.")
        } catch {
            LogE("GroupTotalsViewModel: \(#function) Failed to fetch group \(groupId): \(error).")
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
        guard let group, let userId = preference.user?.id else {
            viewState = .initial
            return
        }

        let summaries: [GroupTotalSummary]
        switch selectedTab {
        case .thisMonth:
            summaries = getTotalSummaryForCurrentMonth(group: group, userId: userId)
        case .thisYear:
            summaries = getTotalSummaryForCurrentYear()
        case .all:
            let groupBalance = group.balances.first(where: { $0.id == userId })?.balanceByCurrency[selectedCurrency.code]
            summaries = groupBalance?.totalSummary ?? []
        }

        // Calculate summary data for selected tab and currency
        summaryData = summaries.reduce(into: GroupMemberSummary(
            groupTotalSpending: 0.00, totalPaidAmount: 0.00, totalShare: 0.00,
            paidAmount: 0.00, receivedAmount: 0.00, changeInBalance: 0.00
        )) { result, summary in
            let currencySummary = summary.summary
            result.groupTotalSpending += currencySummary.groupTotalSpending
            result.totalPaidAmount += currencySummary.totalPaidAmount
            result.totalShare += currencySummary.totalShare
            result.paidAmount += currencySummary.paidAmount
            result.receivedAmount += currencySummary.receivedAmount
            result.changeInBalance += currencySummary.changeInBalance
        }
    }

    private func getTotalSummaryForCurrentYear() -> [GroupTotalSummary] {
        guard let userId = preference.user?.id, let group else {
            viewState = .initial
            return []
        }
        let currentYear = Calendar.current.component(.year, from: Date())
        let groupBalance = group.balances.first(where: { $0.id == userId })?.balanceByCurrency[selectedCurrency.code]
        return groupBalance?.totalSummary.filter {
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
