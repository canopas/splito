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

    @FocusState var isAmountFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 0) {
                if .noInternet == viewModel.viewState || .somethingWentWrong == viewModel.viewState {
                    ErrorView(isForNoInternet: viewModel.viewState == .noInternet,
                              onClick: viewModel.fetchInitialViewData)
                } else if case .loading = viewModel.viewState {
                    LoaderView()
                } else {
                    ScrollView {
                        VStack(alignment: .center, spacing: 0) {
                            VSpacer(16)

                            VStack(alignment: .center, spacing: 16) {
                                HStack(alignment: .center, spacing: 24) {
                                    ProfileCardView(name: viewModel.payerName,
                                                    imageUrl: viewModel.payer?.imageUrl, geometry: geometry)

                                    Button {
                                        viewModel.switchPayerAndReceiver()
                                    } label: {
                                        Image(.transactionIcon)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 42, height: 42)
                                    }

                                    ProfileCardView(name: viewModel.payableName,
                                                    imageUrl: viewModel.receiver?.imageUrl, geometry: geometry)
                                }

                                Divider()
                                    .frame(height: 1)
                                    .background(dividerColor)

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

                            AddAmountView(amount: $viewModel.amount, showCurrencyPicker: $viewModel.showCurrencyPicker,
                                          selectedCurrencySymbol: viewModel.selectedCurrency.symbol,
                                          isAmountFocused: $isAmountFocused)

                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 16)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)

                    AddNoteImageFooterView(date: $viewModel.paymentDate, showImageDisplayView: $viewModel.showImageDisplayView,
                                           showImagePickerOptions: $viewModel.showImagePickerOptions,
                                           image: viewModel.paymentImage,
                                           imageUrl: viewModel.paymentImageUrl,
                                           isNoteEmpty: (viewModel.paymentNote.isEmpty && viewModel.paymentReason.isEmpty),
                                           handleNoteBtnTap: viewModel.handleNoteBtnTap,
                                           handleCameraTap: viewModel.handleCameraTap,
                                           handleAttachmentTap: viewModel.handleAttachmentTap,
                                           handleActionSelection: viewModel.handleActionSelection(_:))
                }
            }
            .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .task { isAmountFocused = true }
        .onTapGesture { isAmountFocused = false }
        .onDisappear { isAmountFocused = false }
        .background(surfaceColor)
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationTitleTextView(text: viewModel.transactionId != nil ? "Edit payment" : "Record a payment")
            }
            ToolbarItem(placement: .topBarTrailing) {
                CheckmarkButton(showLoader: viewModel.showLoader) {
                    Task {
                        let isSucceed = await viewModel.handleSaveAction()
                        if isSucceed {
                            dismiss()
                        } else {
                            viewModel.showSaveFailedError()
                        }
                    }
                }
            }
        }
        .toastView(toast: $viewModel.toast)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePickerView(cropOption: .square, sourceType: !viewModel.sourceTypeIsCamera ? .photoLibrary : .camera,
                            image: $viewModel.paymentImage, isPresented: $viewModel.showImagePicker)
        }
        .fullScreenCover(isPresented: $viewModel.showCurrencyPicker) {
            NavigationStack {
                CurrencyPickerView(selectedCurrency: $viewModel.selectedCurrency,
                                   isPresented: $viewModel.showCurrencyPicker)
            }
        }
        .sheet(isPresented: $viewModel.showAddNoteEditor) {
            NavigationStack {
                AddNoteView(viewModel: AddNoteViewModel(group: viewModel.group, note: viewModel.paymentNote,
                                                        payment: viewModel.transaction,
                                                        paymentReason: viewModel.paymentReason,
                                                        handleSaveNoteTap: viewModel.handleNoteSaveBtnTap(note:reason:)))
            }
        }
    }
}

struct DatePickerView: View {

    @Binding var date: Date

    private let maximumDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    @State private var tempDate: Date
    @State private var showDatePicker = false

    init(date: Binding<Date>) {
        self._date = date
        self._tempDate = State(initialValue: date.wrappedValue)
    }

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
        .onTapGestureForced {
            tempDate = date
            showDatePicker = true
            UIApplication.shared.endEditing()
        }
        .sheet(isPresented: $showDatePicker) {
            VStack(spacing: 20) {
                NavigationBarTopView(title: "Choose date", leadingButton: EmptyView(),
                                     trailingButton: DismissButton(padding: (16, 0), foregroundColor: primaryText,
                                                                   onDismissAction: {
                                        showDatePicker = false
                                     })
                                     .fontWeight(.regular)
                )
                .padding(.leading, 16)

                ScrollView {
                    DatePicker("", selection: $tempDate, in: ...maximumDate, displayedComponents: [.date])
                        .labelsHidden()
                        .datePickerStyle(.graphical)
                        .id(tempDate)
                        .padding(10)
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
