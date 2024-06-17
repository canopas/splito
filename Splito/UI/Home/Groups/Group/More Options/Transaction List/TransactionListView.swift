//
//  TransactionListView.swift
//  Splito
//
//  Created by Nirali Sonani on 14/06/24.
//

import SwiftUI
import BaseStyle
import Data

struct TransactionListView: View {

    @StateObject var viewModel: TransactionListViewModel

    var body: some View {
        VStack {
            if case .loading = viewModel.currentViewState {
                LoaderView()
            } else if case .hasTransaction = viewModel.currentViewState {
                VStack(alignment: .leading, spacing: 0) {
                    VSpacer(20)

                    TransactionListWithDetailView(viewModel: viewModel)

                    VSpacer(40)
                }
            } else if case .noTransaction = viewModel.currentViewState {
                EmptyTransactionView()
            }
        }
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .navigationBarTitle("Group settings", displayMode: .inline)
        .onAppear(perform: viewModel.fetchGroupAndTransactions)
    }
}

private struct TransactionListWithDetailView: View {

    @ObservedObject var viewModel: TransactionListViewModel

    var groupedTransactions: [String: [TransactionWithUser]] = [:]

    init(viewModel: TransactionListViewModel) {
        self.viewModel = viewModel

        self.groupedTransactions = Dictionary(grouping: viewModel.transactionsWithUser
            .sorted { $0.transaction.date.dateValue() > $1.transaction.date.dateValue() }) { transaction in
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMMM yyyy"
                return dateFormatter.string(from: transaction.transaction.date.dateValue())
            }
    }

    var body: some View {
        List {
            Group {
                ForEach(groupedTransactions.keys.sorted(by: viewModel.sortMonthYearStrings), id: \.self) { month in
                    Section(header: sectionHeader(month: month)) {
                        ForEach(groupedTransactions[month]!, id: \.transaction.id) { transaction in
                            TransactionItemView(transactionWithUser: transaction)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(backgroundColor)
        }
        .listStyle(.plain)
        .frame(maxWidth: isIpad ? 600 : .infinity, alignment: .leading)
    }

    private func sectionHeader(month: String) -> some View {
        return Text(month)
            .font(.subTitle2())
            .foregroundStyle(primaryText)
            .padding(.bottom, 8)
    }
}

private struct TransactionItemView: View {

    @Inject var preference: SplitoPreference

    let transaction: Transactions

    private var userName: String = ""

    init(transactionWithUser: TransactionWithUser) {
        self.transaction = transactionWithUser.transaction

        if let user = preference.user, transactionWithUser.user.id == user.id {
            userName = "You"
        } else {
            userName = transactionWithUser.user.nameWithLastInitial
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(transaction.date.dateValue().shortDateWithNewLine)
                .font(.body1())
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)

            Image(systemName: "doc.plaintext")
                .resizable()
                .frame(width: 22)
                .font(.system(size: 14).weight(.light))
                .foregroundStyle(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(disableText.opacity(0.2))

            Text("\(userName) paid \(transaction.amount) to \(userName)")
                .font(.body1(17))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
    }
}

private struct EmptyTransactionView: View {

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            VSpacer()

            Text("No transactions found")
                .font(.subTitle2())
                .lineSpacing(2)
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            VSpacer()
        }
        .frame(alignment: .center)
    }
}
