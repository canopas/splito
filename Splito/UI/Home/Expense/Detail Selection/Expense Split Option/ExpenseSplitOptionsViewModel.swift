//
//  ExpenseSplitOptionsViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 22/04/24.
//

import Data
import BaseStyle
import SwiftUI

class ExpenseSplitOptionsViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var expenseRepository: ExpenseRepository

    @Published private(set) var expenseAmount: Double = 0
    @Published private(set) var splitAmount: Double = 0
    @Published private(set) var totalFixedAmount: Double = 0
    @Published private(set) var totalPercentage: Double = 0
    @Published private(set) var totalShares: Double = 0

    @Published private(set) var groupMembers: [AppUser] = []
    @Published private(set) var shares: [String: Double] = [:]
    @Published private(set) var percentages: [String: Double] = [:]
    @Published private(set) var fixedAmounts: [String: Double] = [:]

    @Published var selectedTab: SplitType
    @Published private(set) var viewState: ViewState = .loading

    @Published var selectedMembers: [String] {
        didSet {
            splitAmount = expenseAmount / Double(selectedMembers.count)
        }
    }

    let selectedCurrency: String

    var isAllSelected: Bool {
        members.count == selectedMembers.count
    }

    private var members: [String] = []
    private var handleSplitTypeSelection: ((_ splitData: [String: Double], _ splitType: SplitType) -> Void)

    init(amount: Double, selectedCurrency: String, splitType: SplitType = .equally,
         splitData: [String: Double], members: [String], selectedMembers: [String],
         handleSplitTypeSelection: @escaping ((_ splitData: [String: Double], _ splitType: SplitType) -> Void)) {
        self.expenseAmount = amount
        self.selectedCurrency = selectedCurrency
        self.selectedTab = splitType
        self.members = members
        self.selectedMembers = selectedMembers
        self.handleSplitTypeSelection = handleSplitTypeSelection
        super.init()

        if splitType == .percentage {
            percentages = splitData
            totalPercentage = splitData.values.reduce(0, +)
        } else if splitType == .fixedAmount {
            fixedAmounts = splitData.mapValues { $0.rounded(to: 2) }
            totalFixedAmount = fixedAmounts.values.reduce(0, +)
        } else if splitType == .shares {
            shares = splitData
            totalShares = splitData.values.reduce(0, +)
        }
        splitAmount = expenseAmount / Double(selectedMembers.count)

        fetchInitialMembersData()
    }

    func fetchInitialMembersData() {
        Task {
            await fetchGroupMembersDetail()
        }
    }

    // MARK: - Data Loading
    private func fetchGroupMembersDetail() async {
        var users: [AppUser] = []

        for memberId in members {
            let user = await fetchMemberData(for: memberId)
            guard let user else {
                viewState = .initial
                return
            }
            users.append(user)
            if let splitAmount = calculateFixedAmountForMember(memberId: memberId) {
                fixedAmounts[memberId] = splitAmount
            }
        }

        self.groupMembers = users
        self.totalFixedAmount = fixedAmounts.values.reduce(0, +)
        self.viewState = .initial
    }

    private func fetchMemberData(for memberId: String) async -> AppUser? {
        do {
            let member = try await userRepository.fetchUserBy(userID: memberId)
            LogD("ExpenseSplitOptionsViewModel: \(#function) Member fetched successfully.")
            return member
        } catch {
            LogE("ExpenseSplitOptionsViewModel: \(#function) Failed to fetch member \(memberId): \(error).")
            handleServiceError()
            return nil
        }
    }

    func calculateFixedAmountForMember(memberId: String) -> Double? {
        switch selectedTab {
        case .equally:
            if selectedMembers.contains(memberId) {
                return calculateEqualSplitAmount(memberId: memberId, amount: expenseAmount, splitTo: selectedMembers)
            }
        case .fixedAmount:
            return fixedAmounts[memberId]
        case .percentage:
            return calculatePercentageSplitAmount(memberId: memberId, amount: expenseAmount,
                                                  splitTo: percentages.map({ $0.key }), splitData: percentages)
        case .shares:
            return calculateSharesSplitAmount(memberId: memberId, amount: expenseAmount,
                                              splitTo: shares.map({ $0.key }), splitData: shares)
        }
        return nil
    }

    // MARK: - User Actions
    func handleTabItemSelection(_ selection: SplitType) {
        selectedTab = selection
    }

    func checkIsMemberSelected(_ memberId: String) -> Bool {
        return selectedMembers.contains(memberId)
    }

    func updateFixedAmount(for memberId: String, amount: Double) {
        fixedAmounts[memberId] = amount.rounded(to: 2)
        totalFixedAmount = fixedAmounts.values.reduce(0, +)
    }

    func updatePercentage(for memberId: String, percentage: Double) {
        percentages[memberId] = percentage
        totalPercentage = percentages.values.reduce(0, +)
    }

    func updateShare(for memberId: String, share: Double) {
        shares[memberId] = share
        totalShares = shares.values.reduce(0, +)
    }

    func handleAllBtnAction() {
        guard let userId = preference.user?.id else { return }

        selectedMembers = isAllSelected ? [userId] : members
        updateFixedAmountsForEqualType()
    }

    func handleMemberSelection(_ memberId: String) {
        if selectedMembers.contains(memberId) {
            selectedMembers.removeAll(where: { $0 == memberId })
        } else {
            selectedMembers.append(memberId)
        }
        updateFixedAmountsForEqualType()
    }

    private func updateFixedAmountsForEqualType() {
        // Remove members from fixedAmounts who are not selected
        let selectedMemberIds = Set(selectedMembers)
        fixedAmounts.keys.filter { !selectedMemberIds.contains($0) }.forEach { fixedAmounts.removeValue(forKey: $0) }

        // Recalculate the amounts for the selected members
        for memberId in selectedMembers {
            fixedAmounts[memberId] = calculateEqualSplitAmount(memberId: memberId, amount: expenseAmount, splitTo: selectedMembers)
        }
    }

    func handleDoneAction(completion: (Bool) -> Void) {
        switch selectedTab {
        case .equally:
            if selectedMembers.isEmpty {
                showAlertFor(title: "Whoops!", message: "You must select at least one person to split with.")
                return completion(false)
            }
        case .fixedAmount:
            if totalFixedAmount != expenseAmount {
                let amountDescription = totalFixedAmount < expenseAmount ? "short" : "over"
                let differenceAmount = totalFixedAmount < expenseAmount ? (expenseAmount - totalFixedAmount) : (totalFixedAmount - expenseAmount)

                showAlertFor(title: "Whoops!", message: "The amounts do not add up to the total cost of \(expenseAmount.formattedCurrency(selectedCurrency)). You are \(amountDescription) by \(differenceAmount.formattedCurrency(selectedCurrency)).")
                return completion(false)
            }
        case .percentage:
            if totalPercentage != 100 {
                let amountDescription = totalPercentage < 100 ? "short" : "over"
                let differenceAmount = totalPercentage < 100 ? (String(format: "%.0f", 100 - totalPercentage)) : (String(format: "%.0f", totalPercentage - 100))

                showAlertFor(title: "Whoops!", message: "The shares do not add up to 100%. You are \(amountDescription) by \(differenceAmount)%")
                return completion(false)
            }
        case .shares:
            if totalShares <= 0 {
                showAlertFor(title: "Whoops!", message: "You must assign a non-zero share to at least one person.")
                return completion(false)
            }
        }

        handleSplitTypeSelection(getSplitData(), selectedTab)
        completion(true)
    }

    private func getSplitData() -> [String: Double] {
        switch selectedTab {
        case .fixedAmount:
            return fixedAmounts.filter { $0.value != 0 }
        case .percentage:
            return percentages.filter { $0.value != 0 }
        case .shares:
            return shares.filter { $0.value != 0 }
        case .equally:
            return fixedAmounts.filter { $0.value != 0 }
        }
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
extension ExpenseSplitOptionsViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }
}

extension SplitType {
    var tabItem: ImageResource {
        switch self {
        case .equally:
            return .equalIcon
        case .fixedAmount:
            return .fixedAmountIcon
        case .percentage:
            return .percentageIcon
        case .shares:
            return .sharesIcon
        }
    }

    var selectedTabItem: ImageResource {
        switch self {
        case .equally:
            return .selectedEqualIcon
        case .fixedAmount:
            return .selectedFixedAmount
        case .percentage:
            return .selectedPercentageIcon
        case .shares:
            return .selectedSharesIcon
        }
    }
}
