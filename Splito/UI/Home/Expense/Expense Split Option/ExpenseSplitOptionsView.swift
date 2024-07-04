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

    @StateObject var viewModel: ExpenseSplitOptionsViewModel

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ZStack {
                    ScrollView {
                        VStack(spacing: 50) {
                            Divider()
                                .frame(height: 1)
                                .background(outlineColor.opacity(0.4))

                            switch viewModel.selectedTab {
                            case .equally:
                                SplitOptionsTopView(title: "Split equally", subtitle: "Select which people owe an equal share.")
                            case .percentage:
                                SplitOptionsTopView(title: "Split by percentages", subtitle: "Enter the percentage split that's fair for your situation.")
                            case .shares:
                                SplitOptionsTopView(title: "Split by share", subtitle: "Great for time-based splitting (2 nights -> 2 shares) and splitting across families (family of 3 -> 3 shares).")
                            }

                            ExpenseSplitOptionsTabView(viewModel: viewModel)

                            VSpacer(80)
                        }
                    }
                    .scrollIndicators(.hidden)

                    SplitOptionsBottomView(viewModel: viewModel)
                }
            }
        }
        .interactiveDismissDisabled()
        .background(backgroundColor)
        .navigationBarTitle("Split options", displayMode: .inline)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    viewModel.handleDoneAction {
                        dismiss()
                    }
                }
                .foregroundStyle(primaryColor)
            }
        }
    }
}

private struct SplitOptionsTopView: View {

    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title.localized)
                .font(.subTitle1())
                .foregroundStyle(primaryText)

            Text(subtitle.localized)
                .font(.body1())
                .foregroundStyle(secondaryText)
        }
        .padding(.horizontal, 20)
        .multilineTextAlignment(.center)
    }
}

private struct SplitOptionsBottomView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        switch viewModel.selectedTab {
        case .equally:
            ExpenseSplitAmountView(memberCount: viewModel.selectedMembers.count, splitAmount: viewModel.splitAmount,
                                   isAllSelected: viewModel.isAllSelected, onAllBtnTap: viewModel.handleAllBtnAction)
        case .percentage:
            BottomInfoCardView(title: "\(String(format: "%.0f", viewModel.totalPercentage))% of 100%",
                               value: "\(String(format: "%.0f", 100 - viewModel.totalPercentage))% left")
        case .shares:
            BottomInfoCardView(title: "\(String(format: "%.0f", viewModel.totalShares)) total shares")
        }
    }
}

private struct ExpenseSplitAmountView: View {

    let memberCount: Int
    let splitAmount: Double
    let isAllSelected: Bool

    let onAllBtnTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(alignment: .center) {
                Spacer()

                VStack(alignment: .center) {
                    if memberCount == 0 {
                        Text("You must select at least one person to split with.")
                            .font(.body2())
                            .foregroundStyle(awarenessColor)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("\(splitAmount.formattedCurrency)/person")
                            .font(.Header3())
                            .foregroundStyle(primaryText)
                        Text("(\(memberCount) people)")
                            .font(.body1())
                            .foregroundStyle(secondaryText)
                    }
                }
                .padding(20)

                Spacer()

                HStack(alignment: .center, spacing: 20) {
                    Divider()
                        .frame(width: 1)
                        .background(outlineColor.opacity(0.4))

                    Text("All")
                        .font(.Header3())
                        .foregroundStyle(primaryText)

                    if isAllSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundStyle(successColor)
                    } else {
                        Circle()
                            .strokeBorder(outlineColor.opacity(0.3), lineWidth: 1)
                            .frame(width: 28, height: 28)
                    }
                }
                .padding(20)
                .onTouchGesture { onAllBtnTap() }
            }
            .frame(height: 80)
            .background(backgroundColor)
            .shadow(color: primaryText.opacity(0.1), radius: 5, x: 0, y: -5)
        }
    }
}

private struct BottomInfoCardView: View {

    let title: String
    var value: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(alignment: .center) {
                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    Text(title.localized)
                        .font(.Header3())
                        .foregroundColor(primaryText)

                    if value != nil {
                        Text(value!.localized)
                            .font(.body1())
                            .foregroundColor(secondaryText)
                    }
                }
                .padding(20)

                Spacer()
            }
            .frame(height: 80)
            .background(backgroundColor)
            .shadow(color: primaryText.opacity(0.1), radius: 5, x: 0, y: -5)
        }
    }
}

#Preview {
    ExpenseSplitOptionsView(viewModel: ExpenseSplitOptionsViewModel(amount: 0, members: [], selectedMembers: [], handleSplitTypeSelection: { _, _, _, _   in }))
}
