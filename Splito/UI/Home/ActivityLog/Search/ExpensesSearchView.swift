//
//  ExpensesSearchView.swift
//  Splito
//
//  Created by Amisha Italiya on 30/12/24.
//

import SwiftUI
import BaseStyle
import Data

struct ExpensesSearchView: View {

    @StateObject var viewModel: ExpensesSearchViewModel

    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) var dismiss

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 0) {
                if .noInternet == viewModel.viewState || .somethingWentWrong == viewModel.viewState {
                    ErrorView(isForNoInternet: viewModel.viewState == .noInternet, onClick: viewModel.fetchInitialExpenses)
                } else if case .loading = viewModel.viewState {
                    LoaderView()
                    Spacer(minLength: 60)
                } else {
                    SearchBar(text: $viewModel.searchedExpense, isFocused: $isFocused, placeholder: "Search...")
                        .padding(.vertical, -7)
                        .padding(.horizontal, 3)
                        .overlay(content: {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(outlineColor, lineWidth: 1)
                        })
                        .focused($isFocused)
                        .padding(.horizontal, 16)

                    if case .noExpense = viewModel.viewState {
                        EmptyStateView(geometry: geometry)
                    } else if case .hasExpense = viewModel.viewState {
                        ExpenseListView(viewModel: viewModel, geometry: geometry)
                    }
                }
            }
        }
        .task { isFocused = true }
        .onTapGestureForced { isFocused = false }
        .background(surfaceColor)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toastView(toast: $viewModel.toast)
        .alertView.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                DismissButton(iconSize: (22, .regular), foregroundColor: primaryText,
                              onDismissAction: { dismiss() })
            }
        }
    }
}

private struct ExpenseListView: View {

    @ObservedObject var viewModel: ExpensesSearchViewModel

    let geometry: GeometryProxy

    var body: some View {
        List {
            Group {
                if !viewModel.groupExpenses.isEmpty {
                    ForEach(viewModel.groupExpenses.keys.sorted(by: sortMonthYearStrings), id: \.self) { month in
                        Section(header: sectionHeader(month: month)) {
                            ForEach(viewModel.groupExpenses[month] ?? [], id: \.expense.id) { expense in
                                GroupExpenseItemView(expenseWithUser: expense,
                                                     isLastItem: expense.expense == (viewModel.groupExpenses[month] ?? []).last?.expense)
                                .contentShape(Rectangle())
                                .highPriorityGesture(
                                    TapGesture().onEnded {
                                        viewModel.handleExpenseItemTap(expense: expense.expense)
                                    }
                                )
                                .id(expense.expense.id)
                            }
                        }
                    }

                    if viewModel.hasMoreExpenses {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .onAppear(perform: viewModel.loadMoreExpenses)
                            .opacity(viewModel.isExpensesLoading ? 1 : 0)
                            .padding(.vertical, 8)
                    }
                } else if viewModel.groupExpenses.isEmpty {
                    ExpenseNotFoundView(minHeight: geometry.size.height - 90, searchedExpense: viewModel.searchedExpense)
                }
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(surfaceColor)
        }
        .listStyle(.plain)
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
    }
}
