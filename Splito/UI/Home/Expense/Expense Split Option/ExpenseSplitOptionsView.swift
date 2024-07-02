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

                            SplitOptionsTabView(viewModel: viewModel)

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

private struct SplitOptionsTabView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        VStack(spacing: 30) {
            HStack(spacing: 0) {
                ForEach(SplitType.allCases, id: \.self) { type in
                    Picker("Split Option", selection: $viewModel.selectedTab) {
                        Image(systemName: type.image)
                            .tag(type)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal, 12)
            }

            switch viewModel.selectedTab {
            case .equally:
                EqualShareView(viewModel: viewModel)
            case .percentage:
                PercentageView(viewModel: viewModel)
            case .shares:
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
                .font(.subTitle1())
                .foregroundStyle(primaryText)

            Text(subtitle)
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
            BottomInfoCardView(
                title: "\(String(format: "%.0f", viewModel.totalPercentage))% of 100%",
                value: "\(String(format: "%.0f", 100 - viewModel.totalPercentage))% left"
            )
        case .shares:
            BottomInfoCardView(title: "\(String(format: "%.0f", viewModel.totalShares)) total shares")
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

    let member: AppUser
    let isSelected: Bool

    let onTap: () -> Void

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
        .onTouchGesture(onTap)
    }
}

private struct PercentageView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.groupMembers, id: \.id) { member in
                MemberCellView(
                    value: Binding(
                        get: { viewModel.percentages[member.id] ?? 0 },
                        set: { viewModel.updatePercentage(for: member.id, percentage: $0) }
                    ),
                    member: member,
                    suffixText: "%"
                )
            }
        }
    }
}

private struct ShareView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.groupMembers, id: \.id) { member in
                MemberCellView(
                    value: Binding(
                        get: { viewModel.shares[member.id] ?? 0 },
                        set: { viewModel.updateShare(for: member.id, share: $0) }
                    ),
                    member: member,
                    suffixText: "share(s)",
                    totalShares: viewModel.totalShares,
                    expenseAmount: viewModel.totalAmount
                )
            }
        }
    }
}

private struct MemberCellView: View {

    @Binding var value: Double

    let member: AppUser
    let suffixText: String
    var totalShares: Double?
    var expenseAmount: Double?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                MemberProfileImageView(imageUrl: member.imageUrl)

                VStack(alignment: .leading, spacing: 4) {
                    Text(member.fullName)
                        .font(.subTitle1())
                        .foregroundStyle(primaryText)

                    if totalShares != nil {
                        let calculatedValue = totalShares! == 0 ? 0 : ((expenseAmount!) * value / (totalShares!))
                        Text((calculatedValue).formattedCurrency)
                            .font(.body2())
                            .foregroundStyle(disableText)
                    }
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    TextField("0", value: $value, formatter: NumberFormatter())
                        .font(.subTitle1())
                        .keyboardType(.decimalPad)
                        .frame(width: 70)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Text(suffixText)
                        .font(.body1())
                        .foregroundStyle(primaryText)
                }
                .fixedSize()
            }
            .padding(.horizontal, 16)

            Divider()
                .frame(height: 1)
                .background(outlineColor.opacity(0.3))
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
                    Text(title)
                        .font(.Header3())
                        .foregroundColor(primaryText)

                    if value != nil {
                        Text(value!)
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
