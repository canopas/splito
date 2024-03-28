//
//  ChoosePayerView.swift
//  Splito
//
//  Created by Amisha Italiya on 27/03/24.
//

import Data
import SwiftUI
import BaseStyle
import Kingfisher

struct ChoosePayerView: View {

    @ObservedObject var viewModel: ChoosePayerViewModel

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Group:: \(viewModel.groupId)")
        }
        .background(backgroundColor)
        .navigationBarTitle("Choose payer", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                }
            }
        }
    }
}

// struct PayerCellView: View {
//
//    var member: Member
//
//    var body: some View {
//        HStack(alignment: .center, spacing: 16) {
//            if let imageUrl = member.imageUrl, let url = URL(string: imageUrl) {
//                KFImage(url)
//                    .placeholder({ _ in
//                        ImageLoaderView()
//                    })
//                    .setProcessor(ResizingImageProcessor(referenceSize: CGSize(width: (50 * UIScreen.main.scale), height: (50 * UIScreen.main.scale)), mode: .aspectFill))
//                    .resizable()
//                    .scaledToFill()
//                    .frame(width: 50, height: 50, alignment: .center)
//                    .clipShape(RoundedRectangle(cornerRadius: 10))
//            } else {
//                Image(.group)
//                    .resizable()
//                    .scaledToFill()
//                    .frame(width: 50, height: 50, alignment: .center)
//                    .clipShape(RoundedRectangle(cornerRadius: 10))
//            }
//
//            Text(group.name)
//                .font(.subTitle2())
//                .foregroundColor(primaryText)
//
//            Spacer()
//
//            Image(.checkMarkTick)
//                .resizable()
//                .frame(width: 24, height: 24)
//
//        }
//        .background(backgroundColor)
//    }
// }

#Preview {
    ChoosePayerView(viewModel: ChoosePayerViewModel(groupId: ""))
}
