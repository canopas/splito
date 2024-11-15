//
//  ChooseMultiplePayerViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 08/07/24.
//

import Data
import BaseStyle

class ChooseMultiplePayerViewModel: BaseViewModel, ObservableObject {

    @Inject var groupRepository: GroupRepository

    @Published var groupId: String

    @Published private(set) var expenseAmount: Double = 0
    @Published private(set) var totalAmount: Double

    @Published private(set) var groupMembers: [AppUser] = []
    @Published private(set) var membersAmount: [String: Double] = [:]

    @Published var currentViewState: ViewState = .loading

    @Published private(set) var dismissChoosePayerFlow: () -> Void

    var onPayerSelection: (([String: Double]) -> Void)

    init(groupId: String, selectedPayers: [String: Double] = [:], expenseAmount: Double,
         onPayerSelection: @escaping (([String: Double]) -> Void), dismissChoosePayerFlow: @escaping () -> Void) {
        self.groupId = groupId
        self.membersAmount = selectedPayers
        self.expenseAmount = expenseAmount
        self.totalAmount = selectedPayers.map { $0.value }.reduce(0, +)
        self.onPayerSelection = onPayerSelection
        self.dismissChoosePayerFlow = dismissChoosePayerFlow
        super.init()

        if membersAmount.count == 1 {
            membersAmount[membersAmount.keys.first ?? ""] = expenseAmount
            totalAmount = expenseAmount
        }

        fetchGroupWithMembersData()
    }

    func fetchGroupWithMembersData() {
        Task {
            await self.fetchGroupWithMembers()
        }
    }

    private func fetchGroupWithMembers() async {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            guard let group else {
                currentViewState = .initial
                return
            }
            groupMembers = try await groupRepository.fetchMembersBy(memberIds: group.members)
            currentViewState = .initial
        } catch {
            handleServiceError()
        }
    }

    func updateAmount(for memberId: String, amount: Double) {
        membersAmount[memberId] = amount
        totalAmount = membersAmount.values.reduce(0, +)
    }

    func handleDoneBtnTap() {
        if totalAmount != expenseAmount {
            let amountDescription = totalAmount < expenseAmount ? "short" : "over"
            let differenceAmount = totalAmount < expenseAmount ? (expenseAmount - totalAmount) : (totalAmount - expenseAmount)

            showAlertFor(title: "Oops!",
                         message: "The payment values do not add up to the total cost of \(expenseAmount.formattedCurrency). You are \(amountDescription) by \(differenceAmount.formattedCurrency).")
            return
        }

        onPayerSelection(membersAmount.filter({ $0.value != 0 }))
        dismissChoosePayerFlow()
    }

    // MARK: - Error Handling
    private func handleServiceError() {
        if !networkMonitor.isConnected {
            currentViewState = .noInternet
        } else {
            currentViewState = .somethingWentWrong
        }
    }
}

extension ChooseMultiplePayerViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }
}
