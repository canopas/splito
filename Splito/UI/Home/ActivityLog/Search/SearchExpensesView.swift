//
//  SearchExpensesView.swift
//  Splito
//
//  Created by Nirali Sonani on 30/12/24.
//

import SwiftUI
import BaseStyle
import Data

struct SearchExpensesView: View {

    @StateObject var viewModel: SearchExpensesViewModel

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if .noInternet == viewModel.viewState || .somethingWentWrong == viewModel.viewState {
                ErrorView(isForNoInternet: viewModel.viewState == .noInternet, onClick: {
                    viewModel.fetchInitialExpenses()
                })
            } else if case .loading = viewModel.viewState {
                LoaderView()
                Spacer(minLength: 60)
            } else {
                if case .noExpense = viewModel.viewState {

                } else if case .hasExpense = viewModel.viewState {
                    VSpacer(4)

                    SearchBar(text: $viewModel.searchedExpense, isFocused: $isFocused, placeholder: "Search groups")
                        .padding(.vertical, -7)
                        .padding(.horizontal, 3)
                        .overlay(content: {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(outlineColor, lineWidth: 1)
                        })
                        .focused($isFocused)
                        .task {
                            isFocused = true
                        }
                        .padding([.horizontal, .top], 16)
                        .padding(.bottom, 8)

                    ExpenseListView(viewModel: viewModel)
                }
            }
        }
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
    }
}

private struct ExpenseListView: View {

    @ObservedObject var viewModel: SearchExpensesViewModel

    var body: some View {
        GeometryReader { geometry in
            List {
                Group {
                    if !viewModel.groupExpenses.isEmpty {
                        ForEach(viewModel.groupExpenses.keys.sorted(by: sortMonthYearStrings), id: \.self) { month in
                            Section(header: sectionHeader(month: month)) {
                                ForEach(viewModel.groupExpenses[month] ?? [], id: \.expense.id) { expense in
                                    GroupExpenseItemView(expenseWithUser: expense,
                                                         isLastItem: expense.expense == (viewModel.groupExpenses[month] ?? []).last?.expense)
                                    .onTouchGesture {
                                        viewModel.handleExpenseItemTap(expenseId: expense.expense.id ?? "")
                                    }
                                    .id(expense.expense.id)
                                }
                            }
                        }

                        if viewModel.hasMoreExpenses {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .onAppear(perform: viewModel.loadMoreExpenses)
                                .padding(.vertical, 8)
                        }
                    } else if viewModel.groupExpenses.isEmpty {
                        ExpenseNotFoundView(geometry: geometry, searchedExpense: viewModel.searchedExpense)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(surfaceColor)
            }
            .listStyle(.plain)
        }
    }

    private func sectionHeader(month: String) -> some View {
        HStack(spacing: 0) {
            Text(month)
                .font(.Header4())
                .foregroundStyle(primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
            Spacer()
        }
        .onTapGestureForced {
            UIApplication.shared.endEditing()
        }
    }
}
