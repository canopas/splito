//
//  GroupHomeView.swift
//  Splito
//
//  Created by Amisha Italiya on 05/03/24.
//

import SwiftUI
import BaseStyle

struct GroupHomeView: View {

    @StateObject var viewModel: GroupHomeViewModel

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if case .loading = viewModel.groupState {
                LoaderView()
            } else if case .noMember = viewModel.groupState {
                AddMemberState(viewModel: .constant(viewModel))
            } else if case .noExpense = viewModel.groupState {
                NoExpenseView()
            } else if case .hasExpense = viewModel.groupState {
                VSpacer(10)

                GroupExpenseListView(viewModel: viewModel, isFocused: $isFocused, onSearchBarAppear: {
                    isFocused = true
                })
                .focused($isFocused)
            }
        }
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .navigationBarTitle(viewModel.group?.name ?? "", displayMode: .inline)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .fullScreenCover(isPresented: $viewModel.showSettleUpSheet) {
            if !(viewModel.memberOwingAmount.isEmpty) {
                GroupSettleUpRouteView(appRoute: .init(root: .GroupSettleUpView(groupId: viewModel.group?.id ?? ""))) {
                    viewModel.showSettleUpSheet = false
                }
            } else {
                GroupSettleUpRouteView(appRoute: .init(root: .GroupWhoIsPayingView(groupId: viewModel.group?.id ?? "", isPaymentSettled: true))) {
                    viewModel.showSettleUpSheet = false
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.showTransactionsSheet) {
            GroupTransactionsRouteView(appRoute: .init(root: .TransactionListView(groupId: viewModel.group?.id ?? ""))) {
                viewModel.showTransactionsSheet = false
            }
        }
        .fullScreenCover(isPresented: $viewModel.showBalancesSheet) {
            NavigationStack {
                GroupBalancesView(viewModel: GroupBalancesViewModel(groupId: viewModel.group?.id ?? ""))
            }
        }
        .fullScreenCover(isPresented: $viewModel.showGroupTotalSheet) {
            NavigationStack {
                GroupTotalsView(viewModel: GroupTotalsViewModel(groupId: viewModel.group?.id ?? ""))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if viewModel.groupState == .hasExpense {
                        Button(action: viewModel.handleSearchOptionTap) {
                            Label("Search", systemImage: "magnifyingglass")
                        }
                    }
                    Button(action: viewModel.handleSettingsOptionTap) {
                        Label("Settings", systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
            }
        }
        .onAppear(perform: viewModel.fetchGroupAndExpenses)
        .onDisappear {
            isFocused = false
            viewModel.onSearchBarCancelBtnTap()
        }
    }
}

struct GroupOptionsListView: View {

    var isSettleUpEnable: Bool
    let showTransactionsOption: Bool

    let onSettleUpTap: () -> Void
    let onTransactionsTap: () -> Void
    let onBalanceTap: () -> Void
    let onTotalsTap: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                GroupOptionsButtonView(text: "Settle up", isForSettleUp: isSettleUpEnable, onTap: onSettleUpTap)

                if showTransactionsOption {
                    GroupOptionsButtonView(text: "Transactions", onTap: onTransactionsTap)
                }

                GroupOptionsButtonView(text: "Balances", onTap: onBalanceTap)

                GroupOptionsButtonView(text: "Totals", onTap: onTotalsTap)
            }
            .padding(.bottom, 4)
            .padding(.vertical, 6)
            .padding(.horizontal, 20)
        }
    }
}

private struct GroupOptionsButtonView: View {

    let text: String
    var isForSettleUp = false

    let onTap: () -> Void

    var body: some View {
        Text(text.localized)
            .font(.subTitle2())
            .foregroundColor(isForSettleUp ? .white : primaryText)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(isForSettleUp ? settleUpColor : backgroundColor)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6).stroke(outlineColor, lineWidth: 1)
            )
            .shadow(color: secondaryText.opacity(0.2), radius: 1, x: 0, y: 1)
            .onTouchGesture { onTap() }
    }
}

private struct AddMemberState: View {

    @Binding var viewModel: GroupHomeViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("You're the only one here!")
                .font(.subTitle1())
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)

            Button {
                viewModel.handleAddMemberClick()
            } label: {
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: "person.fill.badge.plus")
                        .resizable()
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 30)

                    Text("Invite members")
                        .foregroundStyle(.white)
                        .font(.headline)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(primaryColor)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.scale)
        }
        .padding(.horizontal, 22)
    }
}

private struct NoExpenseView: View {

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("No expenses here yet.")
                .font(.subTitle4(17))
                .foregroundStyle(primaryText)

            Text("Tap the plus button to add an expense with any group.")
                .font(.body1(18))
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 30)
    }
}

#Preview {
    GroupHomeView(viewModel: GroupHomeViewModel(router: .init(root: .GroupHomeView(groupId: "")), groupId: "", onGroupSelected: ({_ in})))
}
