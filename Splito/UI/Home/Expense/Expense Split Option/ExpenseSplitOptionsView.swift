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
                            case .fixedAmount:
                                SplitOptionsTopView(title: "Split by share", subtitle: "Great for time-based splitting (2 nights -> 2 shares) and splitting across families (family of 3 -> 3 shares).")
                            }

                            SplitOptionsTabView(viewModel: viewModel)
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

private struct SplitOptionsTabView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        VStack(spacing: 30) {
            Picker("Split Option", selection: $viewModel.selectedTab) {
                Text("=")
                    .tag(SplitType.equally)
                Text("%")
                    .tag(SplitType.percentage)
                Text("|||")
                    .tag(SplitType.fixedAmount)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 12)

            switch viewModel.selectedTab {
            case .equally:
                EqualShareView(viewModel: viewModel)
            case .percentage:
                PercentageView(viewModel: viewModel)
            case .fixedAmount:
                ShareView(viewModel: viewModel)
            }
        }
    }
}

private struct SplitOptionsTopView: View {

    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.Header4())

            Text(subtitle)
                .font(.body1())
        }
        .padding(.horizontal, 20)
        .foregroundStyle(primaryText)
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
            TotalPercentageView(totalPercentage: viewModel.totalPercentage)
        case .fixedAmount:
            TotalSharesView(totalShares: viewModel.totalShares)
        }
    }
}

private struct EqualShareView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.groupMembers, id: \.id) { member in
                ExpenseMemberCellView(member: member, isSelected: viewModel.checkIsMemberSelected(member.id)) {
                    viewModel.handleMemberSelection(member.id)
                }
            }
        }
    }
}

private struct ExpenseMemberCellView: View {

    var member: AppUser
    var isSelected: Bool

    var onTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 20) {
                MemberProfileImageView(imageUrl: member.imageUrl)

                Text(member.fullName)
                    .font(.subTitle1())
                    .foregroundStyle(primaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 26, height: 26)
                        .foregroundStyle(successColor)
                } else {
                    Circle()
                        .strokeBorder(outlineColor.opacity(0.3), lineWidth: 1)
                        .frame(width: 26, height: 26)
                }
            }
            .padding(.horizontal, 16)

            Divider()
                .frame(height: 1)
                .background(outlineColor.opacity(0.3))
        }
        .onTouchGesture {
            onTap()
        }
    }
}

private struct ExpenseSplitAmountView: View {

    var memberCount: Int
    var splitAmount: Double
    var isAllSelected: Bool

    let onAllBtnTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(alignment: .center) {
                Spacer()

                VStack(alignment: .center) {
                    Text("\(splitAmount.formattedCurrency)/person")
                        .font(.Header3())
                        .foregroundStyle(primaryText)
                    Text("(\(memberCount) people)")
                        .font(.body1())
                        .foregroundStyle(secondaryText)
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

private struct TotalPercentageView: View {

    var totalPercentage: Double

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(alignment: .center) {
                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    Text("\(String(format: "%.0f", totalPercentage))% of 100%")
                        .font(.Header3())
                        .foregroundColor(primaryText)

                    Text("\(String(format: "%.0f", 100 - totalPercentage))% left")
                        .font(.body1())
                        .foregroundColor(secondaryText)
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

private struct TotalSharesView: View {

    var totalShares: Double

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(alignment: .center) {
                Spacer()

                Text("\(String(format: "%.0f", totalShares)) total shares")
                    .font(.Header3())
                    .foregroundColor(primaryText)
                    .padding(20)

                Spacer()
            }
            .frame(height: 80)
            .background(backgroundColor)
            .shadow(color: primaryText.opacity(0.1), radius: 5, x: 0, y: -5)
        }
    }
}

private struct PercentageView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(viewModel.groupMembers, id: \.id) { member in
                    PercentageMemberCellView(percentage: Binding(
                        get: { viewModel.percentages[member.id] ?? 0 },
                        set: { viewModel.updatePercentage(for: member.id, percentage: $0) }
                    ), member: member, onPercentageChange: {_ in

                    })
                }
            }
            .padding()
        }
    }
}

private struct PercentageMemberCellView: View {

    @Binding var percentage: Double

    var member: AppUser
    var onPercentageChange: (Double) -> Void

    var body: some View {
        HStack(spacing: 20) {
            MemberProfileImageView(imageUrl: member.imageUrl)
            Text(member.fullName)
                .font(.subTitle1())
                .foregroundStyle(primaryText)

            Spacer()

            TextField("0", value: $percentage, formatter: NumberFormatter())
                .keyboardType(.decimalPad)
                .frame(width: 50)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .multilineTextAlignment(.trailing)
                .onChange(of: percentage) { newValue in
                    onPercentageChange(newValue)
                }

            Text("%")
                .font(.subTitle1())
                .foregroundStyle(primaryText)
        }
        .padding(.horizontal, 16)
    }
}

private struct ShareView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        Text("Share View")
        // Implement share-based splitting logic here
    }
}

#Preview {
    ExpenseSplitOptionsView(viewModel: ExpenseSplitOptionsViewModel(amount: 0, members: [], selectedMembers: [], onMemberSelection: { _ in }))
}
