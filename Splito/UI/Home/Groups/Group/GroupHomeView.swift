//
//  GroupHomeView.swift
//  Splito
//
//  Created by Amisha Italiya on 05/03/24.
//

import SwiftUI
import BaseStyle

struct GroupHomeView: View {
    @EnvironmentObject var homeRouteViewModel: HomeRouteViewModel

    @StateObject var viewModel: GroupHomeViewModel

    @FocusState private var isFocused: Bool
    @State private var sheetHeight: CGFloat = 400.0

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                if case .loading = viewModel.groupState {
                    LoaderView()
                } else {
                    if case .noMember = viewModel.groupState {
                        EmptyStateView(title: "You’re the only one here!", subtitle: "Invite some friends and make this group come alive!", buttonTitle: "Invite Member", image: .inviteFriends, geometry: geometry, onClick: viewModel.handleAddMemberClick)
                    } else if case .noExpense = viewModel.groupState {
                        EmptyStateView(geometry: geometry, onClick: viewModel.openAddExpenseSheet)
                    } else if case .hasExpense = viewModel.groupState {
                        GroupExpenseListView(viewModel: viewModel, isFocused: $isFocused) {
                            isFocused = true
                        }
                        .focused($isFocused)
                    }

                    if viewModel.groupState != .noMember && viewModel.showAddExpenseBtn {
                        PrimaryButton(text: "Add expense", onClick: viewModel.openAddExpenseSheet)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .onDisappear {
            if viewModel.showSearchBar {
                isFocused = false
                viewModel.onSearchBarCancelBtnTap()
            }
        }
        .onAppear {
            homeRouteViewModel.updateSelectedGroup(id: viewModel.groupId)
        }
        .fullScreenCover(isPresented: $viewModel.showAddExpenseSheet) {
            ExpenseRouteView()
        }
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
        .sheet(isPresented: $viewModel.showSimplifyInfoSheet) {
            SimplifyInfoSheetView()
                .fixedSize(horizontal: false, vertical: true)
                .modifier(BottomSheetHeightModifier(height: $sheetHeight))
                .presentationDetents([.height(sheetHeight)])
                .presentationCornerRadius(24)
        }
        .fullScreenCover(isPresented: $viewModel.showTransactionsSheet) {
            GroupTransactionsRouteView(appRoute: .init(root: .TransactionListView(groupId: viewModel.group?.id ?? ""))) {
                viewModel.showTransactionsSheet = false
            }
            .animation(nil)
        }
        .fullScreenCover(isPresented: $viewModel.showBalancesSheet) {
            NavigationStack {
                GroupBalancesView(viewModel: GroupBalancesViewModel(router: viewModel.router, groupId: viewModel.group?.id ?? ""))
            }
        }
        .fullScreenCover(isPresented: $viewModel.showGroupTotalSheet) {
            NavigationStack {
                GroupTotalsView(viewModel: GroupTotalsViewModel(groupId: viewModel.group?.id ?? ""))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text(viewModel.group?.name ?? "")
                    .font(.Header2())
                    .foregroundStyle(primaryText)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ToolbarButtonView(systemImageName: "magnifyingglass", onClick: viewModel.handleSearchOptionTap)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ToolbarButtonView(systemImageName: "gearshape", onClick: viewModel.handleSettingsOptionTap)
            }
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
            HStack(spacing: 8) {
                GroupOptionsButtonView(text: "Settle up", isForSettleUp: isSettleUpEnable, onTap: onSettleUpTap)

                if showTransactionsOption {
                    GroupOptionsButtonView(text: "Transactions", onTap: onTransactionsTap)
                }

                GroupOptionsButtonView(text: "Balances", onTap: onBalanceTap)

                GroupOptionsButtonView(text: "Totals", onTap: onTotalsTap)
            }
            .padding([.horizontal, .bottom], 16)
            .padding(.top, 27)
        }
    }
}

private struct GroupOptionsButtonView: View {

    let text: String
    var isForSettleUp = false

    let onTap: () -> Void

    var body: some View {
        Text(text.localized)
            .font(.buttonText())
            .foregroundColor(isForSettleUp ? primaryDarkText : primaryText)
            .padding(.vertical, 8)
            .padding(.horizontal, 24)
            .background(isForSettleUp ? settleUpColor : container2Color)
            .cornerRadius(30)
            .onTouchGesture(onTap)
    }
}

private struct EmptyStateView: View {

    var title: String = "No expenses here yet."
    var subtitle: String = "Add an expense to get this party started."
    var buttonTitle: String?

    var image: ImageResource = .noExpense
    let geometry: GeometryProxy

    let onClick: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 0) {
                Spacer()

                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width * 0.5, height: geometry.size.width * 0.4)
                    .padding(.bottom, 40)

                Text(title.localized)
                    .font(.Header1())
                    .foregroundStyle(primaryText)
                    .padding(.bottom, 16)

                Text(subtitle.localized)
                    .font(.subTitle1())
                    .foregroundStyle(disableText)
                    .tracking(-0.2)
                    .lineSpacing(4)

                Spacer()
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(minHeight: geometry.size.height - 85, maxHeight: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)

        if let buttonTitle {
            PrimaryButton(text: buttonTitle, onClick: onClick)
                .padding(16)
        }
    }
}

private struct SimplifyInfoSheetView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(outlineColor)
                    .frame(width: 40, height: 4)
                    .padding(.vertical, 30)

                Text("Why do I owe this person?")
                    .font(.Header2())
                    .foregroundStyle(primaryText)
                    .padding(.bottom, 24)

                Group {
                    Text("\"Simplify debts\" is ENABLED in this group. This feature shuffles \"who owes who\" to minimize repayments. For example:")
                        .padding(.bottom, 24)

                    Image(.simplifyDebtsExample)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 277, height: 146)
                        .padding(.bottom, 24)

                    Text("Ana borrows $10 from Bob")
                        .padding(.bottom, 4)

                    Text("Bob borrows $10 from Charlie")
                        .padding(.bottom, 24)

                    Text("In a group with \"simplify debts\" enabled, Splito will tell Ana to repay Charlie $10. Bob does nothing. This is the most efficient way for the group to settle up. With simplify debts enabled, it's normal to owe someone who didn't directly loan you money.")
                }
                .font(.body3())
                .foregroundStyle(disableText)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
        }
    }
}

struct ToolbarButtonView: View {

    var systemImageName: String?
    var imageIcon: ImageResource?

    let onClick: () -> Void

    var body: some View {
        Button {
            onClick()
        } label: {
            if let imageIcon {
                Image(imageIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(primaryText)
            } else if let systemImageName {
                Image(systemName: systemImageName)
                    .resizable()
                    .scaledToFit()
                    .font(.system(size: 13).weight(.semibold))
            }
        }
        .foregroundStyle(primaryText)
    }
}

#Preview {
    GroupHomeView(viewModel: GroupHomeViewModel(router: .init(root: .GroupHomeView(groupId: "")), groupId: ""))
}
