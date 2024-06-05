//
//  GroupPaymentView.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import SwiftUI
import BaseStyle

struct GroupPaymentView: View {

    @StateObject var viewModel: GroupPaymentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(alignment: .center, spacing: 20) {
                        Text("Hello World")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .navigationBarTitle("Record a payment", displayMode: .inline)
    }
}

#Preview {
    GroupPaymentView(viewModel: GroupPaymentViewModel(router: nil, groupId: ""))
}
