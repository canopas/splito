//
//  GroupPaymentViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import Data
import Foundation

class GroupPaymentViewModel: BaseViewModel, ObservableObject {
    
    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var groupRepository: GroupRepository
    @Inject private var transactionRepository: TransactionRepository
    
    @Published var amount: Double = 0
    @Published var paymentDate = Date()
    @Published private(set) var showLoader: Bool = false
    
    @Published private(set) var payer: AppUser?
    @Published private(set) var receiver: AppUser?
    @Published private(set) var viewState: ViewState = .loading
    
    var payerName: String {
        guard let user = preference.user else { return "" }
        return user.id == payerId ? "You" : payer?.nameWithLastInitial ?? "Unknown"
    }
    
    var payableName: String {
        guard let user = preference.user else { return "" }
        return user.id == receiverId ? "You" : receiver?.nameWithLastInitial ?? "Unknown"
    }
    
    private var group: Groups?
    private let groupId: String
    
    let transactionId: String?
    private let payerId: String
    private let receiverId: String
    private var transaction: Transactions?
    private let router: Router<AppRoute>?
    
    init(router: Router<AppRoute>, transactionId: String?, groupId: String, payerId: String, receiverId: String, amount: Double) {
        self.router = router
        self.amount = abs(amount)
        self.groupId = groupId
        self.payerId = payerId
        self.receiverId = receiverId
        self.transactionId = transactionId
        
        super.init()
        
        Task {
            await fetchGroup()
            await fetchTransaction()
            await getPayerUserDetail()
            await getPayableUserDetail()
        }
    }
    
    // MARK: - Data Loading
    private func fetchGroup() async {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            self.group = group
            self.viewState = .initial
        } catch {
            handleServiceError(error as! ServiceError)
        }
    }
    
    func fetchTransaction() async {
        guard let transactionId else { return }
        
        viewState = .loading
        do {
            let transaction = try await transactionRepository.fetchTransactionBy(groupId: groupId, transactionId: transactionId)
            self.transaction = transaction
            self.paymentDate = transaction.date.dateValue()
            self.viewState = .initial
        } catch {
            handleServiceError(error as! ServiceError)
        }
    }
    
    private func getPayerUserDetail() async {
        do {
            let user = try await userRepository.fetchUserBy(userID: payerId)
            if let user {
                payer = user
            }
        } catch {
            handleServiceError(error as! ServiceError)
        }
    }
    
    private func getPayableUserDetail() async {
        do {
            let user = try await userRepository.fetchUserBy(userID: receiverId)
            if let user {
                receiver = user
            }
        } catch {
            handleServiceError(error as! ServiceError)
        }
    }
    
    func handleSaveAction(completion: @escaping () -> Void) async {
        guard amount > 0 else {
            showAlertFor(title: "Whoops!", message: "You must enter an amount.")
            return
        }
        guard let userId = preference.user?.id else { return }
        
        if let transaction {
            var newTransaction = transaction
            newTransaction.amount = amount
            newTransaction.date = .init(date: paymentDate)
            
            await updateTransaction(transaction: newTransaction, oldTransaction: transaction, completion: completion)
        } else {
            let transaction = Transactions(payerId: payerId, receiverId: receiverId, addedBy: userId,
                                           amount: amount, date: .init(date: paymentDate))
            
            await addTransaction(transaction: transaction, completion: completion)
        }
    }
    
    private func addTransaction(transaction: Transactions, completion: @escaping () -> Void) async {
        showLoader = true

        do {
            let transaction = try await transactionRepository.addTransaction(groupId: groupId, transaction: transaction)
            self.showLoader = false
            await updateGroupMemberBalance(transaction: transaction, updateType: .Add, completion: completion)
            NotificationCenter.default.post(name: .addTransaction, object: transaction)
        } catch {
            self.showLoader = false
            handleServiceError(error as! ServiceError)
        }
    }
    
    private func updateTransaction(transaction: Transactions, oldTransaction: Transactions, completion: @escaping () -> Void) async {            
        showLoader = true
        
        do {
            try await transactionRepository.updateTransaction(groupId: groupId, transaction: transaction)
            self.showLoader = false
            await self.updateGroupMemberBalance(transaction: transaction, updateType: .Update(oldTransaction: oldTransaction), completion: completion)
            NotificationCenter.default.post(name: .updateTransaction, object: transaction)
        } catch {
            self.showLoader = false
            handleServiceError(error as! ServiceError)
        }
    }
    
    private func updateGroupMemberBalance(transaction: Transactions, updateType: TransactionUpdateType, completion: @escaping () -> Void) async {
        guard var group else { return }
        
        let memberBalance = getUpdatedMemberBalanceFor(transaction: transaction, group: group, updateType: updateType)
        group.balances = memberBalance
        
        do {
            try await groupRepository.updateGroup(group: group)
            viewState = .initial
            completion()
        } catch {
            handleServiceError(error as! ServiceError)
        }
    }
}

// MARK: - View States
extension GroupPaymentViewModel {
    enum ViewState {
        case initial
        case loading
    }
}

public func handleServiceError(_ error: ServiceError) {
    
}
