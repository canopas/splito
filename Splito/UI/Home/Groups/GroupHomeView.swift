//
//  GroupHomeView.swift
//  Splito
//
//  Created by Amisha Italiya on 05/03/24.
//

import SwiftUI
import BaseStyle

struct GroupHomeView: View {

    @ObservedObject var viewModel: GroupHomeViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("You do not have any groups yet.")
                .font(.Header1(22 ))
                .foregroundColor(primaryText)

            Text("Groups make it easy to split apartment bills, share travel expenses, and more.")
                .font(.subTitle3(15))
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)

            Button {
                viewModel.router.push(.CreateGroup)
            } label: {
                HStack(spacing: 20) {
                    Image(systemName: "person.3.fill")
                        .resizable()
                        .foregroundColor(.white)
                        .frame(width: 42, height: 22)

                    Text("Start a group")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(primaryColor)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.top, 10)
            .buttonStyle(.scale)
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .padding(.horizontal, 22)
    }
}

#Preview {
    GroupHomeView(viewModel: GroupHomeViewModel(router: .init(root: .GroupHome)))
}
