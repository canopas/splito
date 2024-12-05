//
//  GroupPaymentViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import Data
import BaseStyle
import UIKit
import SwiftUI
import AVFoundation
import FirebaseFirestore

class GroupPaymentViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var groupRepository: GroupRepository
    @Inject private var transactionRepository: TransactionRepository

    @Published var amount: Double = 0
    @Published var paymentDate = Date()
    @Published var paymentImage: UIImage?

    @Published var paymentNote: String = ""
    @Published var paymentReason: String = ""
    @Published private(set) var paymentImageUrl: String?

    @Published var showImagePicker = false
    @Published var showAddNoteEditor = false
    @Published var showImagePickerOptions = false
    @Published private(set) var showLoader: Bool = false
    @Published private(set) var sourceTypeIsCamera = false

    @Published private(set) var payer: AppUser?
    @Published private(set) var receiver: AppUser?
    @Published private(set) var viewState: ViewState = .loading

    var payerName: String {
        guard let user = preference.user else { return "" }
        return user.id == payerId ? "You" : payer?.nameWithLastInitial ?? "Unknown"
    }

    var payableName: String {
        guard let user = preference.user else { return "" }
        return user.id == receiverId ? "you" : receiver?.nameWithLastInitial ?? "unknown"
    }

    var group: Groups?
    private let groupId: String

    let transactionId: String?
    private var payerId: String
    private var receiverId: String
    var transaction: Transactions?
    private let router: Router<AppRoute>?

    init(router: Router<AppRoute>, transactionId: String?, groupId: String,
         payerId: String, receiverId: String, amount: Double) {
        self.router = router
        self.amount = abs(amount)
        self.groupId = groupId
        self.payerId = payerId
        self.receiverId = receiverId
        self.transactionId = transactionId

        super.init()

        fetchInitialViewData()
    }

    func fetchInitialViewData() {
        Task {
            await fetchGroup()
            await fetchTransaction()
            await getPayerUserDetail()
            await getPayableUserDetail()
        }
    }

    func switchPayerAndReceiver() {
        let temp = payer
        payer = receiver
        receiver = temp

        payerId = payer?.id ?? ""
        receiverId = receiver?.id ?? ""
    }

    // MARK: - Data Loading
    private func fetchGroup() async {
        do {
            self.group = try await groupRepository.fetchGroupBy(id: groupId)
            self.viewState = .initial
            LogD("GroupPaymentViewModel: \(#function) Group fetched successfully.")
        } catch {
            LogE("GroupPaymentViewModel: \(#function) Failed to fetch group \(groupId): \(error).")
            handleServiceError()
        }
    }

    func fetchTransaction() async {
        guard let transactionId else { return }

        do {
            viewState = .loading
            self.transaction = try await transactionRepository.fetchTransactionBy(groupId: groupId,
                                                                                  transactionId: transactionId)

            paymentDate = transaction?.date.dateValue() ?? Date.now
            paymentNote = transaction?.note ?? ""
            paymentImageUrl = transaction?.imageUrl
            paymentReason = transaction?.reason ?? ""

            viewState = .initial
            LogD("GroupPaymentViewModel: \(#function) Payment fetched successfully.")
        } catch {
            LogE("GroupPaymentViewModel: \(#function) Failed to fetch payment \(transactionId): \(error).")
            handleServiceError()
        }
    }

    private func getPayerUserDetail() async {
        do {
            viewState = .loading
            let user = try await userRepository.fetchUserBy(userID: payerId)
            if let user { payer = user }
            viewState = .initial
            LogD("GroupPaymentViewModel: \(#function) Payer fetched successfully.")
        } catch {
            LogE("GroupPaymentViewModel: \(#function) Failed to fetch payer \(payerId): \(error).")
            handleServiceError()
        }
    }

    private func getPayableUserDetail() async {
        do {
            viewState = .loading
            let user = try await userRepository.fetchUserBy(userID: receiverId)
            if let user { receiver = user }
            viewState = .initial
            LogD("GroupPaymentViewModel: \(#function) Payable fetched successfully.")
        } catch {
            LogE("GroupPaymentViewModel: \(#function) Failed to fetch payable \(receiverId): \(error).")
            handleServiceError()
        }
    }

    // MARK: - User Actions
    func handleNoteBtnTap() {
        showAddNoteEditor = true
    }

    func handleNoteSaveBtnTap(note: String, reason: String?) {
        showAddNoteEditor = false
        self.paymentNote = note
        self.paymentReason = reason ?? ""
    }

    func handlePaymentImageTap() {
        UIApplication.shared.endEditing()
        showImagePickerOptions = true
    }

    func handleActionSelection(_ action: ActionsOfSheet) {
        switch action {
        case .camera:
            self.checkCameraPermission {
                self.sourceTypeIsCamera = true
                self.showImagePicker = true
            }
        case .gallery:
            sourceTypeIsCamera = false
            showImagePicker = true
        case .remove:
            withAnimation {
                paymentImage = nil
                paymentImageUrl = nil
            }
        }
    }

    private func checkCameraPermission(authorized: @escaping (() -> Void)) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        authorized()
                    }
                }
            }
            return
        case .restricted, .denied:
            showAlertFor(alert: .init(title: "Important!", message: "Camera access is required to take picture for expenses",
                                      positiveBtnTitle: "Allow", positiveBtnAction: { [weak self] in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
                self?.showAlert = false
            }))
        case .authorized:
            authorized()
        default:
            return
        }
    }

    func showSaveFailedError() {
        guard amount > 0 else { return }

        guard validateGroupMembers() else {
            showAlertFor(message: "This payment involves a person who has left the group, and thus it can no longer be edited. If you wish to change this payment, you must first add that person back to your group.")
            return
        }

        showToastFor(toast: ToastPrompt(type: .error, title: "Oops", message: "Failed to save payment transaction."))
    }

    private func validateGroupMembers() -> Bool {
        guard let group, let payer, let receiver else {
            LogE("GroupPaymentViewModel: \(#function) Missing required group or member information.")
            return false
        }

        return group.members.contains(payer.id) && group.members.contains(receiver.id)
    }

    func handleSaveAction() async -> Bool {
        guard amount > 0 else {
            showAlertFor(title: "Whoops!", message: "Please enter an amount greater than zero.")
            return false
        }

        guard let userId = preference.user?.id else { return false }

        if let transaction {
            var newTransaction = transaction
            newTransaction.amount = amount
            newTransaction.date = .init(date: paymentDate)
            newTransaction.updatedAt = Timestamp()
            newTransaction.updatedBy = userId
            newTransaction.note = paymentNote
            newTransaction.reason = paymentReason

            return await updateTransaction(transaction: newTransaction, oldTransaction: transaction)
        } else {
            let transaction = Transactions(payerId: payerId, receiverId: receiverId, addedBy: userId,
                                           updatedBy: userId, note: paymentNote, reason: paymentReason,
                                           amount: amount, date: .init(date: paymentDate))
            return await addTransaction(transaction: transaction)
        }
    }

    private func addTransaction(transaction: Transactions) async -> Bool {
        guard let group, let payer, let receiver else {
            LogE("GroupPaymentViewModel: \(#function) Missing required group or member information.")
            return false
        }

        do {
            showLoader = true

            self.transaction = try await transactionRepository.addTransaction(group: group, transaction: transaction,
                                                                              members: (payer, receiver), imageData: getImageData())
            NotificationCenter.default.post(name: .addTransaction, object: self.transaction)
            await updateGroupMemberBalance(updateType: .Add)

            showLoader = false
            LogD("GroupPaymentViewModel: \(#function) Payment added successfully.")
            return true
        } catch {
            showLoader = false
            LogE("GroupPaymentViewModel: \(#function) Failed to add payment: \(error).")
            showToastForError()
            return false
        }
    }

    private func updateTransaction(transaction: Transactions, oldTransaction: Transactions) async -> Bool {
        guard let group, let transactionId, let payer, let receiver else {
            LogE("GroupPaymentViewModel: \(#function) Missing required group or member information.")
            return false
        }
        guard validateGroupMembers() else { return false }

        do {
            showLoader = true

            self.transaction = try await transactionRepository.updateTransactionWithImage(imageData: getImageData(), newImageUrl: paymentImageUrl, group: group, transaction: (transaction, oldTransaction), members: (payer, receiver))

            defer {
                NotificationCenter.default.post(name: .updateTransaction, object: self.transaction)
            }

            guard hasTransactionChanged(transaction, oldTransaction: oldTransaction) else { return true }
            await updateGroupMemberBalance(updateType: .Update(oldTransaction: oldTransaction))

            showLoader = false
            LogD("GroupPaymentViewModel: \(#function) Payment updated successfully.")
            return true
        } catch {
            showLoader = false
            LogE("GroupPaymentViewModel: \(#function) Failed to update payment \(transactionId): \(error).")
            showToastForError()
            return false
        }
    }

    private func getImageData() -> Data? {
        let resizedImage = paymentImage?.aspectFittedToHeight(200)
        let imageData = resizedImage?.jpegData(compressionQuality: 0.2)
        return imageData
    }

    private func hasTransactionChanged(_ transaction: Transactions, oldTransaction: Transactions) -> Bool {
        return oldTransaction.payerId != transaction.payerId || oldTransaction.receiverId != transaction.receiverId ||
        oldTransaction.amount != transaction.amount || oldTransaction.isActive != transaction.isActive
    }

    private func updateGroupMemberBalance(updateType: TransactionUpdateType) async {
        guard var group, let transaction, let transactionId = transaction.id else {
            LogE("GroupPaymentViewModel: \(#function) Transaction information not found.")
            showLoader = false
            return
        }

        do {
            let memberBalance = getUpdatedMemberBalanceFor(transaction: transaction, group: group, updateType: updateType)
            group.balances = memberBalance
            try await groupRepository.updateGroup(group: group, type: .none)
            LogD("GroupPaymentViewModel: \(#function) Member balance updated successfully.")
        } catch {
            showLoader = false
            LogE("GroupPaymentViewModel: \(#function) Failed to update member balance for payment \(transactionId): \(error).")
            showToastForError()
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
extension GroupPaymentViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }
}
