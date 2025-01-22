//
//  ExpenseSplitOptionsTabView.swift
//  Splito
//
//  Created by Amisha Italiya on 04/07/24.
//

import SwiftUI
import Data
import BaseStyle

struct ExpenseSplitOptionsTabView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 8) {
                ForEach(SplitType.allCases, id: \.self) { tab in
                    Button {
                        viewModel.handleTabItemSelection(tab)
                    } label: {
                        Image(tab == viewModel.selectedTab ? tab.selectedTabItem : tab.tabItem)
                            .lineLimit(1)
                            .frame(width: 18, height: 18)
                            .foregroundStyle(viewModel.selectedTab == tab ? inversePrimaryText : disableText)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(viewModel.selectedTab == tab ? primaryDarkColor : container2Color)
                            .cornerRadius(30)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .center)

            switch viewModel.selectedTab {
            case .equally:
                SplitOptionsTopView(title: "Split equally", subtitle: "Select which people owe an equal split.")
            case .fixedAmount:
                SplitOptionsTopView(title: "Split by exact amounts", subtitle: "Specify exactly how much each person owes.")
            case .percentage:
                SplitOptionsTopView(title: "Split by percentages", subtitle: "Enter the percentage split that's fair for your situation.")
            case .shares:
                SplitOptionsTopView(title: "Split by shares", subtitle: "Great for time-based splitting (2 nights - 2 shares) and splitting across families (family of 3 - 3 shares).")
            }

            switch viewModel.selectedTab {
            case .equally:
                EqualShareView(viewModel: viewModel)
            case .fixedAmount:
                FixedAmountView(viewModel: viewModel)
            case .percentage:
                PercentageView(viewModel: viewModel)
            case .shares:
                ShareView(viewModel: viewModel)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
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
                .foregroundStyle(disableText)
        }
        .padding(.horizontal, 16)
        .multilineTextAlignment(.center)
    }
}

private struct EqualShareView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.groupMembers, id: \.id) { member in
                ExpenseMemberCellView(member: member, isSelected: viewModel.checkIsMemberSelected(member.id), isLastCell: member == viewModel.groupMembers.last) {
                    viewModel.handleMemberSelection(member.id)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct ExpenseMemberCellView: View {

    @Inject private var preference: SplitoPreference

    let member: AppUser
    let isSelected: Bool
    let isLastCell: Bool

    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                MemberProfileImageView(imageUrl: member.imageUrl)

                Text(member.id == preference.user?.id ? "You" : member.fullName)
                    .font(.subTitle2())
                    .foregroundStyle(primaryText)

                Spacer()

                CircularSelectionView(isSelected: isSelected, onClick: onTap)
            }
            .padding(.horizontal, 16)

            if !isLastCell {
                Divider()
                    .frame(height: 1)
                    .background(dividerColor)
            }
        }
        .onTouchGesture(onTap)
    }
}

private struct FixedAmountView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        VStack(spacing: 16) {
            let currencySymbol = Currency.getCurrencyFromCode(viewModel.selectedCurrency).symbol
            ForEach(viewModel.groupMembers, id: \.id) { member in
                MemberCellView(
                    value: Binding(
                        get: { viewModel.fixedAmounts[member.id] ?? 0 },
                        set: { viewModel.updateFixedAmount(for: member.id, amount: $0) }
                    ),
                    member: member, suffixText: currencySymbol,
                    formatString: "%.2f", isLastCell: member == viewModel.groupMembers.last,
                    expenseAmount: viewModel.expenseAmount, amountCurrency: viewModel.selectedCurrency,
                    inputFieldWidth: 70,
                    onChange: { amount in
                        viewModel.updateFixedAmount(for: member.id, amount: amount)
                    }
                )
            }
        }
        .padding(.vertical, 8)
    }
}

private struct PercentageView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.groupMembers, id: \.id) { member in
                MemberCellView(
                    value: Binding(
                        get: { viewModel.percentages[member.id] ?? 0 },
                        set: { viewModel.updatePercentage(for: member.id, percentage: $0) }
                    ),
                    member: member, suffixText: "%",
                    isLastCell: member == viewModel.groupMembers.last,
                    splitAmount: viewModel.calculateFixedAmountForMember(memberId: member.id),
                    expenseAmount: viewModel.expenseAmount, amountCurrency: viewModel.selectedCurrency,
                    onChange: { percentage in
                        viewModel.updatePercentage(for: member.id, percentage: percentage)
                    }
                )
            }
        }
        .padding(.vertical, 8)
    }
}

private struct ShareView: View {

    @ObservedObject var viewModel: ExpenseSplitOptionsViewModel

    var body: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.groupMembers, id: \.id) { member in
                MemberCellView(
                    value: Binding(
                        get: { viewModel.shares[member.id] ?? 0 },
                        set: { viewModel.updateShare(for: member.id, share: $0) }
                    ),
                    member: member, suffixText: "shares",
                    isLastCell: member == viewModel.groupMembers.last,
                    splitAmount: viewModel.calculateFixedAmountForMember(memberId: member.id),
                    expenseAmount: viewModel.expenseAmount, amountCurrency: viewModel.selectedCurrency,
                    onChange: { share in
                        viewModel.updateShare(for: member.id, share: share)
                    }
                )
            }
        }
        .padding(.vertical, 8)
    }
}

struct MemberCellView: View {

    @Inject private var preference: SplitoPreference

    @Binding var value: Double

    let member: AppUser
    let suffixText: String
    let formatString: String
    let isLastCell: Bool

    var splitAmount: Double?
    var expenseAmount: Double
    var amountCurrency: String
    var inputFieldWidth: Double

    let onChange: (Double) -> Void

    @State private var textValue: String

    init(value: Binding<Double>, member: AppUser, suffixText: String, formatString: String = "%.0f", isLastCell: Bool, splitAmount: Double? = nil, expenseAmount: Double, amountCurrency: String, inputFieldWidth: Double = 40, onChange: @escaping (Double) -> Void) {
        self._value = value
        self.member = member
        self.suffixText = suffixText
        self.formatString = formatString
        self.isLastCell = isLastCell
        self.splitAmount = splitAmount
        self.expenseAmount = expenseAmount
        self.amountCurrency = amountCurrency
        self.inputFieldWidth = inputFieldWidth
        self.onChange = onChange
        self._textValue = State(initialValue: value.wrappedValue == 0.0 ? "" : String(format: formatString, value.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                MemberProfileImageView(imageUrl: member.imageUrl)

                VStack(alignment: .leading, spacing: 4) {
                    Text(member.id == preference.user?.id ? "You" : member.fullName)
                        .font(.subTitle2())
                        .foregroundStyle(primaryText)

                    if let splitAmount {
                        Text(splitAmount.formattedCurrencyWithSign(amountCurrency))
                            .font(.body3(12))
                            .foregroundStyle(disableText)
                    }
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    VStack(spacing: 2) {
                        TextField("0", text: $textValue, onCommit: {
                            updateValue(from: textValue)
                        })
                        .font(.body3())
                        .foregroundStyle(secondaryText)
                        .keyboardType(.decimalPad)
                        .tint(primaryColor)
                        .frame(width: inputFieldWidth)

                        Divider()
                            .frame(height: 1)
                            .background(primaryText)
                    }
                    .fixedSize(horizontal: true, vertical: false)

                    Text(suffixText.localized)
                        .font(.body3())
                        .foregroundStyle(primaryText)
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 20)

            if !isLastCell {
                Divider()
                    .frame(height: 1)
                    .background(dividerColor)
            }
        }
        .onChange(of: textValue) { newValue in
            updateValue(from: newValue)
        }
    }

    private func updateValue(from newValue: String) {
        if let doubleValue = Double(newValue) {
            value = doubleValue
        } else {
            value = 0
        }
        onChange(value)
    }
}
