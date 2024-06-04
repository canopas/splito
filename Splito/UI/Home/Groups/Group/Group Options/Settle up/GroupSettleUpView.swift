//
//  GroupSettleUpView.swift
//  Splito
//
//  Created by Amisha Italiya on 03/06/24.
//

import SwiftUI
import BaseStyle

struct GroupSettleUpView: View {

    @StateObject var viewModel: GroupSettleUpViewModel

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if case .loading = viewModel.viewState {
                LoaderView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(backgroundColor)
        .interactiveDismissDisabled()
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .navigationBarTitle("Settle up", displayMode: .inline)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    GroupSettleUpView(viewModel: GroupSettleUpViewModel(groupId: ""))
}
