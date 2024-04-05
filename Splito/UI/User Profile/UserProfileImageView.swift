//
//  UserProfileImageView.swift
//  Splito
//
//  Created by Amisha Italiya on 14/03/24.
//

import SwiftUI
import BaseStyle
import Kingfisher

struct UserProfileImageView: View {

    @Binding private var image: UIImage?

    private let profileImageUrl: String?

    private let handleProfileTap: (() -> Void)

    public init(image: Binding<UIImage?>, profileImageUrl: String?, handleProfileTap: @escaping () -> Void) {
        self._image = image
        self.profileImageUrl = profileImageUrl
        self.handleProfileTap = handleProfileTap
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let urlString = profileImageUrl, let url = URL(string: urlString), image == nil {
                    Circle()
                        .background(
                            Circle()
                                .foregroundColor(containerHighColor)
                        )
                        .frame(width: 106, height: 106, alignment: .center)

                    KFImage(url)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 106, height: 106, alignment: .center)
                        .clipShape(Circle())
                } else {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 106, height: 106, alignment: .center)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .strokeBorder(.clear, lineWidth: 0)
                            .background(
                                Circle()
                                    .foregroundColor(containerHighColor)
                            )
                            .frame(width: 106, height: 106, alignment: .center)

                        Image(.user)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 106, height: 106, alignment: .center)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .overlay {
            VStack(spacing: 0) {
                Image(.profileEditPencil)
                    .padding(8)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32, alignment: .center)
                    .overlay(
                        Circle()
                            .stroke(primaryLightText, lineWidth: 1)
                    )
            }
            .padding([.top, .leading], 75)
            .padding(.bottom, 10)
        }
        .onTapGesture(perform: handleProfileTap)
    }
}
