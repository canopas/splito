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
    @Published private(set) var viewState: ViewState = .initial

    @Published var selectedMembers: [String] {
        didSet {
            splitAmount = expenseAmount / Double(selectedMembers.count)
        }
    }

    var isAllSelected: Bool {
        members.count == selectedMembers.count
    }

    private var members: [String] = []
    private var handleSplitTypeSelection: ((_ members: [String], _ splitData: [String: Double], _ splitType: SplitType) -> Void)

    init(amount: Double, splitType: SplitType = .equally,
         splitData: [String: Double], members: [String], selectedMembers: [String],
         handleSplitTypeSelection: @escaping ((_ members: [String], _ splitData: [String: Double], _ splitType: SplitType) -> Void)) {
        self.expenseAmount = amount
        self.selectedTab = splitType
        self.members = members
        self.selectedMembers = selectedMembers
        self.handleSplitTypeSelection = handleSplitTypeSelection
        super.init()

        if splitType == .percentage {
            percentages = splitData
            totalPercentage = splitData.values.reduce(0, +)
        } else if splitType == .fixedAmount {
            fixedAmounts = splitData
            totalFixedAmount = splitData.values.reduce(0, +)
        } else if splitType == .shares {
            shares = splitData
            totalShares = splitData.values.reduce(0, +)
        }
        splitAmount = expenseAmount / Double(selectedMembers.count)

        Task {
            await fetchUsersData()
        }
    }

    // MARK: - Data Loading
    private func fetchUsersData() async {
        var users: [AppUser] = []

        viewState = .loading

        for memberId in members {
            let user = await fetchUserData(for: memberId)
            guard let user else {
                viewState = .initial
                return
            }
            users.append(user)
            calculateFixedAmountForMember(memberId: memberId)
        }

        self.groupMembers = users
        self.totalFixedAmount = fixedAmounts.values.reduce(0, +)
        self.viewState = .initial
    }

    func fetchUserData(for memberId: String) async -> AppUser? {
        do {
            return try await userRepository.fetchUserBy(userID: memberId)
        } catch {
            viewState = .initial
            handleServiceError(error)
            return nil
        }
    }

    func calculateFixedAmountForMember(memberId: String) {
        switch selectedTab {
        case .equally:
            if selectedMembers.contains(memberId) {
                fixedAmounts[memberId] = splitAmount
            }
        case .fixedAmount:
            break
        case .percentage:
            let calculatedAmount = totalPercentage == 0 ? 0 : (expenseAmount * (Double(percentages[memberId] ?? 0) / totalPercentage))
            fixedAmounts[memberId] = calculatedAmount
        case .shares:
            let calculatedAmount = totalShares == 0 ? 0 : (expenseAmount * (Double(shares[memberId] ?? 0) / totalShares))
            fixedAmounts[memberId] = calculatedAmount
        }
    }

    // MARK: - User Actions
    func handleTabItemSelection(_ selection: SplitType) {
        selectedTab = selection
    }

    func checkIsMemberSelected(_ memberId: String) -> Bool {
        return selectedMembers.contains(memberId)
    }

    func updateFixedAmount(for memberId: String, amount: Double) {
        fixedAmounts[memberId] = amount
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
        if isAllSelected {
            selectedMembers = [preference.user?.id ?? ""]
        } else {
            selectedMembers = members
        }
    }

    func handleMemberSelection(_ memberId: String) {
        if selectedMembers.contains(memberId) {
            selectedMembers.removeAll(where: { $0 == memberId })
        } else {
            selectedMembers.append(memberId)
        }
    }

    func handleDoneAction() {
        if selectedTab == .equally && selectedMembers.count == 0 {
            showAlertFor(title: "Whoops!", message: "You must select at least one person to split with.")
            return
        }

        if selectedTab == .percentage && totalPercentage != 100 {
            let amountDescription = totalPercentage < 100 ? "short" : "over"
            let differenceAmount = totalPercentage < 100 ? (String(format: "%.0f", 100 - totalPercentage)) : (String(format: "%.0f", totalPercentage - 100))

            showAlertFor(title: "Whoops!", message: "The shares do not add up to 100%. You are \(amountDescription) by \(differenceAmount)%")
            return
        }

        if selectedTab == .shares && totalShares <= 0 {
            showAlertFor(title: "Whoops!", message: "You must assign a non-zero share to at least one person.")
            return
        }

        if selectedTab == .fixedAmount && totalFixedAmount != expenseAmount {
            let amountDescription = totalFixedAmount < expenseAmount ? "short" : "over"
            let differenceAmount = totalFixedAmount < expenseAmount ? (expenseAmount - totalFixedAmount) : (totalFixedAmount - expenseAmount)

            showAlertFor(title: "Whoops!", message: "The amounts do not add up to the total cost of \(expenseAmount.formattedCurrency). You are \(amountDescription) by \(differenceAmount.formattedCurrency).")
            return
        }

        handleSplitTypeSelection(selectedMembers, (selectedTab == .fixedAmount) ? fixedAmounts.filter({ $0.value != 0 }) : (selectedTab == .percentage) ? percentages.filter({ $0.value != 0 }) : shares.filter({ $0.value != 0 }), selectedTab)
    }
}

// MARK: - View States
extension ExpenseSplitOptionsViewModel {
    enum ViewState {
        case initial
        case loading
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
