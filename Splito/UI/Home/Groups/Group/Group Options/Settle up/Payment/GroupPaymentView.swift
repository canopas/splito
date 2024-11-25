//
//  GroupPaymentView.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import SwiftUI
import BaseStyle
import Data

struct GroupPaymentView: View {
    @Environment(\.dismiss) var dismiss

    @StateObject var viewModel: GroupPaymentViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 0) {
                if .noInternet == viewModel.viewState || .somethingWentWrong == viewModel.viewState {
                    ErrorView(isForNoInternet: viewModel.viewState == .noInternet, onClick: viewModel.fetchInitialViewData)
                } else if case .loading = viewModel.viewState {
                    LoaderView()
                } else {
                    ScrollView {
                        VStack(alignment: .center, spacing: 0) {
                            VSpacer(16)

                            VStack(alignment: .center, spacing: 16) {
                                HStack(alignment: .center, spacing: 24) {
                                    ProfileCardView(name: viewModel.payerName, imageUrl: viewModel.payer?.imageUrl, geometry: geometry)

                                    Button {
                                        viewModel.switchPayerAndReceiver()
                                    } label: {
                                        Image(.transactionIcon)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 42, height: 42)
                                    }

                                    ProfileCardView(name: viewModel.payableName, imageUrl: viewModel.receiver?.imageUrl, geometry: geometry)
                                }

                                Divider()
                                    .frame(height: 1)
                                    .background(outlineColor)

                                Text("\(viewModel.payerName.localized) paid \(viewModel.payableName.localized)")
                                    .font(.body3())
                                    .foregroundStyle(disableText)
                                    .tracking(0.5)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(container2Color)
                            .cornerRadius(16)

                            VSpacer(16)

                            AmountRowView(amount: $viewModel.amount, subtitle: "Enter amount")

                            VSpacer(16)

                            PaymentDateRow(date: $viewModel.paymentDate, subtitle: "Date")

                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 16)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)

                    PrimaryButton(text: "Done", showLoader: viewModel.showLoader, onClick: {
                        Task {
                            let isSucceed = await viewModel.handleSaveAction()
                            if isSucceed {
                                dismiss()
                            } else {
                                viewModel.showSaveFailedError()
                            }
                        }
                    })
                    .padding([.horizontal, .bottom], 16)
                }
            }
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: viewModel.transactionId != nil ? "Edit payment" : "Record a payment")
            }
        }
    }
}

struct AmountRowView: View {

    @Binding var amount: Double

    let subtitle: String

    @FocusState var isAmountFocused: Bool
    @State private var amountString: String = ""

    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            Text(subtitle.localized)
                .font(.subTitle1())
                .foregroundStyle(primaryText)
                .tracking(-0.2)

            TextField(" ₹ 0.00", text: $amountString)
                .keyboardType(.decimalPad)
                .font(.Header1())
                .tint(primaryColor)
                .foregroundStyle(amountString.isEmpty ? outlineColor : primaryText)
                .focused($isAmountFocused)
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .onChange(of: amountString) { newValue in
                    formatAmount(newValue: newValue)
                }
                .onAppear {
                    amountString = amount == 0 ? "" : String(format: "₹ %.2f", amount)
                    isAmountFocused = true
                }
        }
        .padding(16)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(outlineColor, lineWidth: 1)
        }
    }

    private func formatAmount(newValue: String) {
        // Remove the "₹" symbol and whitespace to process the numeric value
        let numericInput = newValue.replacingOccurrences(of: "₹", with: "").trimmingCharacters(in: .whitespaces)
        if let value = Double(numericInput) {
            amount = value
        } else {
            amount = 0
        }

        // Update amountString to include "₹" prefix
        amountString = numericInput.isEmpty ? "" : "₹ " + numericInput
    }
}

private struct PaymentDateRow: View {

    @Binding var date: Date

    let subtitle: String

    @State private var showDatePicker: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(subtitle.localized)
                .font(.body3())
                .foregroundStyle(disableText)

            DatePickerView(date: $date)
                .padding(16)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(outlineColor, lineWidth: 1)
                }
        }
    }
}

struct DatePickerView: View {

    @Binding var date: Date

    var isForAddExpense: Bool

    private let maximumDate = Calendar.current.date(byAdding: .year, value: 0, to: Date()) ?? Date()

    @State private var tempDate: Date
    @State private var showDatePicker = false

    init(date: Binding<Date>, isForAddExpense: Bool = false) {
        self._date = date
        self.isForAddExpense = isForAddExpense
        self._tempDate = State(initialValue: date.wrappedValue)
    }

    var body: some View {
        HStack {
            if !isForAddExpense {
                Text(date.longDate)
                    .font(.subTitle2())
                    .foregroundStyle(primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                DateDisplayView(date: $date)
            }
        }
        .onTapGestureForced {
            tempDate = date
            showDatePicker = true
            UIApplication.shared.endEditing()
        }
        .sheet(isPresented: $showDatePicker) {
            VStack(spacing: 0) {
                NavigationBarTopView(title: "Choose date", leadingButton: EmptyView(),
                    trailingButton: DismissButton(padding: (16, 0), foregroundColor: primaryText, onDismissAction: {
                        showDatePicker = false
                    })
                    .fontWeight(.regular)
                )
                .padding(.leading, 16)

                ScrollView {
                    DatePicker("", selection: $tempDate, in: ...maximumDate, displayedComponents: .date)
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .labelsHidden()
                        .padding(24)
                        .id(tempDate)
                }
                .scrollIndicators(.hidden)

                Spacer()

                PrimaryButton(text: "Done") {
                    date = tempDate
                    showDatePicker = false
                }
                .padding(16)
            }
            .background(surfaceColor)
        }
    }
}

private struct DateDisplayView: View {

    @Binding var date: Date

    var body: some View {
        HStack(spacing: 8) {
            Text(date.isToday() ? "Today" : date.shortDate)
                .font(.subTitle2())
                .foregroundStyle(primaryText)

            Image(.calendarIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(container2Color)
        .cornerRadius(8)
    }
}
