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
        VStack(alignment: .center) {
            if case .loading = viewModel.currentViewState {
                LoaderView()
            } else {
                VStack(alignment: .center, spacing: 0) {
                    VSpacer(24)

                    TransactionTabView(selectedTab: viewModel.selectedTab,
                                       onSelect: viewModel.handleTabItemSelection(_:))

                    TransactionListWithDetailView(viewModel: viewModel)

                    VSpacer(40)
                }
            }
        }
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .navigationBarTitle("Transactions", displayMode: .inline)
        .onAppear(perform: viewModel.fetchTransactions)
    }
}

private struct TransactionListWithDetailView: View {

    @ObservedObject var viewModel: TransactionListViewModel

    var body: some View {
        GeometryReader { geometry in
            List {
                Group {
                    if viewModel.filteredTransactions.isEmpty {
                        EmptyTransactionView(geometry: geometry)
                    } else {
                        ForEach(viewModel.filteredTransactions.keys.sorted(by: viewModel.sortMonthYearStrings), id: \.self) { month in
                            Section(header: sectionHeader(month: month)) {
                                ForEach(viewModel.filteredTransactions[month]!, id: \.transaction.id) { transaction in
                                    TransactionItemView(transactionWithUser: transaction)
                                        .onTouchGesture {
                                            viewModel.handleTransactionItemTap(transaction.transaction.id)
                                        }
                                        .swipeActions {
                                            Button("Delete") {
                                                viewModel.showTransactionDeleteAlert(transaction.transaction.id)
                                            }
                                            .tint(.red)
                                        }
                                }
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
            .scrollIndicators(.hidden)
            .frame(maxWidth: isIpad ? 600 : .infinity, alignment: .center)
        }
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

    private let transactionWithUser: TransactionWithUser
    private var payerName: String = ""
    private var receiverName: String = ""

    init(transactionWithUser: TransactionWithUser) {
        self.transactionWithUser = transactionWithUser

        if let user = preference.user {
            payerName = transactionWithUser.payer?.id == user.id ? "You" : transactionWithUser.payer?.nameWithLastInitial ?? "Someone"
            receiverName = transactionWithUser.receiver?.id == user.id ? "you" : transactionWithUser.receiver?.nameWithLastInitial ?? "someone"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(transactionWithUser.transaction.date.dateValue().shortDateWithNewLine)
                .font(.body1())
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)

            Divider()
                .frame(width: 1)
                .background(outlineColor)

            Text("\(payerName) paid \(receiverName) \(transactionWithUser.transaction.amount.formattedCurrency).")
                .font(.body1(17))
                .foregroundStyle(primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "list.bullet.rectangle.portrait")
                .resizable()
                .frame(width: 20, height: 24)
                .padding(10)
                .background(containerNormalColor.opacity(0.7))
                .cornerRadius(10)
        }
        .padding(16)
        .background(containerLowColor)
        .cornerRadius(16)
        .padding(.vertical, 8)
    }
}

private struct EmptyTransactionView: View {

    let geometry: GeometryProxy

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Spacer()

            HStack {
                Spacer()
                Text("No transactions found")
                    .font(.subTitle2())
                    .foregroundColor(secondaryText)
                    .multilineTextAlignment(.center)
                Spacer()
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(minHeight: geometry.size.height, maxHeight: .infinity, alignment: .center)
    }
}

private struct TransactionTabView: View {

    let selectedTab: TransactionTabType
    let onSelect: ((TransactionTabType) -> Void)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TransactionTabType.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    Text(tab.tabItem.localized)
                        .font(.body2())
                        .foregroundColor(selectedTab == tab ? surfaceDarkColor : primaryText)
                        .padding(.vertical, 8)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(selectedTab == tab ? surfaceLightColor : Color.clear)
                        .cornerRadius(selectedTab == tab ? 8 : 0)
                        .padding(.all, 2)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .background(containerNormalColor)
        .cornerRadius(8)
        .frame(maxWidth: .infinity, alignment: .center)
        .transaction { transaction in
            transaction.animation = nil
        }
        .padding(.bottom, 10)
        .padding(.horizontal, 12)
    }
}
