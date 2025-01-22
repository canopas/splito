//
//  ExpenseSplitOptionsView.swift.swift
//  Splito
//
//  Created by Amisha Italiya on 22/04/24.
//

import Data
import SwiftUI
import BaseStyle

struct ExpenseSplitOptionsView: View {
    @Environment(\.dismiss) var dismiss

    @StateObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        VStack(spacing: 0) {
            NavigationBarTopView(
                title: "Split options",
                leadingButton: {
                    DismissButton(iconSize: (22, .regular), padding: (16, 0),
                                  foregroundColor: primaryText, onDismissAction: { dismiss() })
                }(),
                trailingButton:
                    CheckmarkButton(padding: (.horizontal, 16)) {
                        viewModel.handleDoneAction { isValidInput in
                            if isValidInput { dismiss() }
                        }
                    }
            )

            Spacer(minLength: 0)

            if .noInternet == viewModel.viewState || .somethingWentWrong == viewModel.viewState {
                ErrorView(isForNoInternet: viewModel.viewState == .noInternet, onClick: viewModel.fetchInitialMembersData)
            } else if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        VSpacer(27)
                        ExpenseSplitOptionsTabView(viewModel: viewModel)
                        Spacer()
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .center)

                SplitOptionsBottomView(viewModel: viewModel)
            }
        }
        .background(surfaceColor)
        .interactiveDismissDisabled()
        .toolbar(.hidden, for: .navigationBar)
        .toastView(toast: $viewModel.toast)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
    }
}

private struct SplitOptionsBottomView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        switch viewModel.selectedTab {
        case .equally:
            let selectedCurrency = viewModel.selectedCurrency
            BottomInfoCardView(title: "\(viewModel.splitAmount.formattedCurrency(selectedCurrency))/person",
                               value: "\(viewModel.selectedMembers.count) people",
                               memberCount: viewModel.selectedMembers.count, isAllSelected: viewModel.isAllSelected,
                               isForEqualSplit: true, onAllBtnTap: viewModel.handleAllBtnAction)
        case .fixedAmount:
            let selectedCurrency = viewModel.selectedCurrency
            BottomInfoCardView(title: "\(viewModel.totalFixedAmount.formattedCurrency(selectedCurrency)) of \(viewModel.expenseAmount.formattedCurrency(selectedCurrency))",
                               value: "\((viewModel.expenseAmount - viewModel.totalFixedAmount).formattedCurrency(selectedCurrency)) left")
        case .percentage:
            BottomInfoCardView(title: "\(String(format: "%.0f", viewModel.totalPercentage))% of 100%",
                               value: "\(String(format: "%.0f", 100 - viewModel.totalPercentage))% left")
        case .shares:
            BottomInfoCardView(title: "\(String(format: "%.0f", viewModel.totalShares)) total shares")
        }
    }
}

struct BottomInfoCardView: View {

    let title: String
    var value: String?

    var memberCount: Int = 1
    var isAllSelected: Bool = true
    var isForEqualSplit: Bool = false

    var onAllBtnTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: isForEqualSplit ? .leading : .center, spacing: 4) {
                if isForEqualSplit && memberCount == 0 {
                    Text("You must select at least one person to split with.")
                        .font(.body1())
                        .foregroundStyle(errorColor)
                        .multilineTextAlignment(.center)
                } else {
                    Text(title.localized)
                        .font(.Header4())
                        .foregroundStyle(inversePrimaryText)

                    if value != nil {
                        Text(value!.localized)
                            .font(.body1())
                            .foregroundStyle(inverseDisableText)
                    }
                }
            }

            if isForEqualSplit {
                Spacer()

                HStack(spacing: 0) {
                    Divider()
                        .frame(width: 1)
                        .background(inverseOutlineColor)

                    Text("All")
                        .font(.buttonText())
                        .foregroundStyle(inversePrimaryText)
                        .padding(.trailing, 8)
                        .padding(.leading, 16)

                    CircularSelectionView(isSelected: isAllSelected, borderColor: inverseOutlineColor, onClick: onAllBtnTap)
                }
                .onTouchGesture {
                    onAllBtnTap?()
                }
            }
        }
        .padding(16)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .bottom)
        .background(primaryDarkColor)
        .shadow(color: primaryText.opacity(0.1), radius: 5, x: 0, y: -5)
    }
}

struct CircularSelectionView: View {

    var isSelected: Bool
    var borderColor: Color = outlineColor

    var onClick: (() -> Void)?

    var body: some View {
        if isSelected {
            CheckmarkButton(iconSize: (20, 28), padding: (.all, 2), onClick: onClick)
                .background(primaryColor)
                .clipShape(.circle)
        } else {
            Circle()
                .stroke(borderColor, lineWidth: 1)
                .frame(width: 24, height: 32)
        }
    }
}
