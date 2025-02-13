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
    @State private var sheetHeight: CGFloat = 400.0

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                if .noInternet == viewModel.groupState || .somethingWentWrong == viewModel.groupState {
                    ErrorView(isForNoInternet: viewModel.groupState == .noInternet, onClick: {
                        viewModel.fetchGroupAndExpenses()
                    })
                } else {
                    if case .loading = viewModel.groupState {
                        LoaderView()
                    } else if case .noMember = viewModel.groupState {
                        EmptyStateView(title: "You’re the only one here!",
                                       subtitle: "Invite some friends and make this group come alive!",
                                       buttonTitle: "Invite Member", image: .inviteFriends,
                                       geometry: geometry, onClick: viewModel.handleInviteMemberClick)
                    } else if case .noExpense = viewModel.groupState {
                        EmptyStateView(buttonTitle: "Add expense", geometry: geometry, onClick: viewModel.openAddExpenseSheet)
                    } else if case .memberNotInGroup = viewModel.groupState {
                        EmptyStateView(title: "You're no longer part of this group.",
                                       subtitle: "You no longer have access to this group's activities, expenses and payments.",
                                       image: .restoreGroupIcon, geometry: geometry)
                    } else if case .deactivateGroup = viewModel.groupState {
                        EmptyStateView(title: "This group has been deleted.",
                                       subtitle: "You can restore it to recover all activities, expenses and payments.",
                                       buttonTitle: "Restore", image: .restoreGroupIcon,
                                       geometry: geometry, onClick: viewModel.handleRestoreGroupAction)
                    } else if case .hasExpense = viewModel.groupState {
                        GroupExpenseListView(viewModel: viewModel, isFocused: $isFocused)
                            .focused($isFocused)
                    }
                }
            }
        }
        .onTapGestureForced {
            UIApplication.shared.endEditing()
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .onDisappear {
            if viewModel.showSearchBar {
                isFocused = false
                viewModel.onSearchBarCancelBtnTap()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !viewModel.showScrollToTopBtn && viewModel.groupState != .noExpense && viewModel.groupState != .deactivateGroup && viewModel.groupState != .memberNotInGroup {
                VStack(spacing: 0) {
                    Spacer()
                    AddExpenseButtonView(onClick: viewModel.openAddExpenseSheet)
                        .padding([.bottom, .trailing], 16)
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: viewModel.group?.name ?? "")
            }
            ToolbarItem(placement: .topBarTrailing) {
                ToolbarButtonView(systemImageName: "magnifyingglass", onClick: viewModel.handleSearchOptionTap)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ToolbarButtonView(systemImageName: "gearshape", onClick: viewModel.handleSettingsOptionTap)
            }
        }
        .fullScreenCover(isPresented: $viewModel.showAddExpenseSheet) {
            ExpenseRouteView(selectedGroupId: viewModel.groupId)
        }
        .fullScreenCover(isPresented: $viewModel.showSettleUpSheet) {
            if !(viewModel.memberOwingAmount.isEmpty) {
                GroupSettleUpRouteView(appRoute: .init(root: .GroupSettleUpView(groupId: viewModel.groupId)))
            } else {
                GroupSettleUpRouteView(appRoute: .init(root: .GroupWhoIsPayingView(groupId: viewModel.groupId, isPaymentSettled: true)))
            }
        }
        .fullScreenCover(isPresented: $viewModel.showTransactionsSheet) {
            GroupTransactionsRouteView(appRoute: .init(root: .TransactionListView(groupId: viewModel.groupId)))
                .onDisappear {
                    viewModel.refetchTransactionsCount()
                }
        }
        .fullScreenCover(isPresented: $viewModel.showBalancesSheet) {
            NavigationStack {
                GroupBalancesView(viewModel: GroupBalancesViewModel(router: viewModel.router, groupId: viewModel.groupId))
            }
        }
        .fullScreenCover(isPresented: $viewModel.showGroupTotalSheet) {
            NavigationStack {
                GroupTotalsView(viewModel: GroupTotalsViewModel(groupId: viewModel.groupId))
            }
        }
        .fullScreenCover(isPresented: $viewModel.showInviteMemberSheet) {
            NavigationStack {
                InviteMemberView(viewModel: InviteMemberViewModel(router: viewModel.router, groupId: viewModel.groupId))
            }
        }
        .sheet(isPresented: $viewModel.showSimplifyInfoSheet) {
            SimplifyInfoSheetView()
                .fixedSize(horizontal: false, vertical: true)
                .modifier(BottomSheetHeightModifier(height: $sheetHeight))
                .presentationDetents([.height(sheetHeight)])
                .presentationCornerRadius(24)
        }
    }
}

struct GroupOptionsListView: View {

    @Binding var showExportOptions: Bool
    @Binding var showShareReportSheet: Bool

    let groupReportUrl: URL?
    let isSettleUpEnable: Bool

    let onExportTap: () -> Void
    let onTotalsTap: () -> Void
    let onBalanceTap: () -> Void
    let onSettleUpTap: () -> Void
    let onTransactionsTap: () -> Void
    let handleExportOptionSelection: (_ option: ExportOptions) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                GroupOptionsButtonView(text: "Settle up", isForSettleUp: isSettleUpEnable, onTap: onSettleUpTap)

                GroupOptionsButtonView(text: "Settlements", onTap: onTransactionsTap)

                GroupOptionsButtonView(text: "Balances", onTap: onBalanceTap)

                GroupOptionsButtonView(text: "Totals", onTap: onTotalsTap)

                GroupOptionsButtonView(text: "Export", onTap: onExportTap)
                    .confirmationDialog("", isPresented: $showExportOptions, titleVisibility: .hidden) {
                        ForEach(ExportOptions.allCases, id: \.self) { option in
                            Button(option.option.localized) {
                                showExportOptions = false
                                handleExportOptionSelection(option)
                            }
                        }
                    }
            }
            .padding([.horizontal, .bottom], 16)
            .padding(.top, 24)
        }
        .sheet(isPresented: $showShareReportSheet) {
            if let reportUrl = groupReportUrl {
                ShareSheetView(activityItems: [reportUrl]) { isCompleted in
                    if isCompleted {
                        showShareReportSheet = false
                    }
                }
            }
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
            .foregroundStyle(isForSettleUp ? .white : primaryText)
            .padding(.vertical, 8)
            .padding(.horizontal, 24)
            .background(isForSettleUp ? infoColor : container2Color)
            .cornerRadius(30)
            .onTouchGesture(onTap)
    }
}

struct EmptyStateView: View {

    var title: String = "No expenses here yet."
    var subtitle: String = "Add an expense to get this party started."
    var buttonTitle: String?

    var image: ImageResource = .noExpense
    let geometry: GeometryProxy
    var minHeight: CGFloat?

    var onClick: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 0) {
                Spacer()

                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width * 0.5, height: geometry.size.width * 0.4)
                    .padding(.bottom, 20)

                Text(title.localized)
                    .font(.Header1())
                    .foregroundStyle(primaryText)
                    .padding(.bottom, 8)

                Text(subtitle.localized)
                    .font(.subTitle1())
                    .foregroundStyle(disableText)
                    .tracking(-0.2)
                    .lineSpacing(4)

                if let buttonTitle {
                    PrimaryButton(text: buttonTitle, onClick: onClick)
                        .padding(.top, 20)
                }

                VSpacer(10)

                Spacer()
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(minHeight: minHeight ?? geometry.size.height - 50, maxHeight: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
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
