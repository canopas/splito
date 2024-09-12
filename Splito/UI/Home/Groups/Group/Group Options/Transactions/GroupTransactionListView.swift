//
//  GroupTransactionListView.swift
//  Splito
//
//  Created by Amisha Italiya on 14/06/24.
//

import SwiftUI
import BaseStyle
import Data

struct GroupTransactionListView: View {

    @StateObject var viewModel: GroupTransactionListViewModel

    var body: some View {
        VStack(alignment: .center) {
            if case .loading = viewModel.currentViewState {
                LoaderView()
            } else {
                VStack(alignment: .center, spacing: 0) {
                    VSpacer(27)

                    TransactionTabView(selectedTab: viewModel.selectedTab,
                                       onSelect: viewModel.handleTabItemSelection(_:))

                    TransactionListWithDetailView(viewModel: viewModel)

                    VSpacer(40)
                }
                .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Transactions")
                    .font(.Header2())
                    .foregroundStyle(primaryText)
            }
        }
    }
}

private struct TransactionListWithDetailView: View {

    @ObservedObject var viewModel: GroupTransactionListViewModel

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                List {
                    Group {
                        if viewModel.filteredTransactions.isEmpty {
                            EmptyTransactionView(geometry: geometry)
                        } else {
                            let firstMonth = viewModel.filteredTransactions.keys.sorted(by: viewModel.sortMonthYearStrings).first

                            ForEach(viewModel.filteredTransactions.keys.sorted(by: viewModel.sortMonthYearStrings), id: \.self) { month in
                                Section(header: sectionHeader(month: month)) {
                                    ForEach(viewModel.filteredTransactions[month] ?? [], id: \.transaction.id) { transaction in
                                        TransactionItemView(transactionWithUser: transaction,
                                                            isLastCell: transaction.transaction.id == (viewModel.filteredTransactions[month] ?? []).last?.transaction.id)
                                        .onTouchGesture {
                                            viewModel.handleTransactionItemTap(transaction.transaction.id)
                                        }
                                        .id(transaction.transaction.id)
                                        .swipeActions {
                                            Button {
                                                viewModel.showTransactionDeleteAlert(transaction.transaction)
                                            } label: {
                                                Image(.deleteIcon)
                                                    .resizable()
                                                    .tint(.clear)
                                            }
                                        }
                                        .onAppear {
                                            if month == firstMonth && viewModel.filteredTransactions[month]?.first?.transaction.id == transaction.transaction.id {
                                                viewModel.manageScrollToTopBtnVisibility(false)
                                            }
                                        }
                                        .onDisappear {
                                            if !viewModel.transactions.isEmpty && month == firstMonth && viewModel.filteredTransactions[month]?.first?.transaction.id == transaction.transaction.id {
                                                viewModel.manageScrollToTopBtnVisibility(true)
                                            }
                                        }

                                        if transaction.transaction.id == viewModel.filteredTransactions[month]?.last?.transaction.id && viewModel.hasMoreTransactions {
                                            ProgressView()
                                                .frame(maxWidth: .infinity, alignment: .center)
                                                .onAppear {
                                                    Task {
                                                        await viewModel.fetchMoreTransactions()
                                                    }
                                                }
                                                .padding(.vertical, 8)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .id("transaction_list")
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(surfaceColor)
                }
                .listStyle(.plain)
                .refreshable {
                    Task {
                        await viewModel.fetchTransactions()
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if viewModel.showScrollToTopBtn {
                        ScrollToTopButton {
                            withAnimation { scrollProxy.scrollTo("transaction_list", anchor: .top) }
                        }
                        .padding([.trailing, .bottom], 16)
                    }
                }
            }
        }
    }

    private func sectionHeader(month: String) -> some View {
        return Text(month)
            .font(.Header4())
            .foregroundStyle(primaryText)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
    }
}

private struct TransactionItemView: View {

    @Inject var preference: SplitoPreference

    let isLastCell: Bool
    private let transactionWithUser: TransactionWithUser
    private var payerName: String = ""
    private var receiverName: String = ""

    init(transactionWithUser: TransactionWithUser, isLastCell: Bool = false) {
        self.transactionWithUser = transactionWithUser
        self.isLastCell = isLastCell

        if let user = preference.user {
            payerName = transactionWithUser.payer?.id == user.id ? "You" : transactionWithUser.payer?.nameWithLastInitial ?? "Someone"
            receiverName = transactionWithUser.receiver?.id == user.id ? "you" : transactionWithUser.receiver?.nameWithLastInitial ?? "someone"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 0) {
                let dateComponents = transactionWithUser.transaction.date.dateValue().dayAndMonthText
                VStack(spacing: 0) {
                    Text(dateComponents.month)
                        .font(.caption1())
                        .foregroundStyle(disableText)
                    Text(dateComponents.day)
                        .font(.Header4())
                        .foregroundStyle(primaryText)
                }
                .multilineTextAlignment(.center)
                .padding(.trailing, 8)

                Image(.transactionIcon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .padding(8)
                    .background(container2Color)
                    .cornerRadius(8)
                    .padding(.trailing, 16)

                HStack(spacing: 0) {
                    Text("\(payerName.localized) paid \(receiverName.localized)")
                        .font(.subTitle2())
                        .foregroundStyle(primaryText)

                    Spacer()

                    Text("\(transactionWithUser.transaction.amount.formattedCurrency)")
                        .font(.subTitle2())
                        .foregroundStyle(transactionWithUser.payer?.id == preference.user?.id ? alertColor : successColor)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 16)

            if !isLastCell {
                Divider()
                    .frame(height: 1)
                    .background(dividerColor)
            }
        }
    }
}

private struct TransactionTabView: View {

    let selectedTab: DateRangeTabType
    let onSelect: ((DateRangeTabType) -> Void)

    var body: some View {
        HStack(spacing: 8) {
            ForEach(DateRangeTabType.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    Text(tab.tabItem.localized)
                        .font(.buttonText())
                        .foregroundStyle(selectedTab == tab ? inversePrimaryText : disableText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 24)
                        .lineLimit(1)
                        .background(selectedTab == tab ? primaryDarkColor : container2Color)
                        .cornerRadius(30)
                        .minimumScaleFactor(0.5)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .transaction { transaction in
            transaction.animation = nil
        }
        .padding(.horizontal, 16)
    }
}

private struct EmptyTransactionView: View {

    let geometry: GeometryProxy

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Spacer()

            Image(.emptyTransactionIcon)
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width * 0.5, height: geometry.size.width * 0.4)
                .padding(.bottom, 40)

            Text("No transactions yet!")
                .font(.Header1())
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)

            Text("Start spending or receiving money to see your transactions here.")
                .font(.subTitle1())
                .foregroundStyle(disableText)
                .tracking(-0.2)
                .lineSpacing(4)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: geometry.size.height - 40, maxHeight: .infinity, alignment: .center)
    }
}
