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

    private var size: (width: CGFloat, height: CGFloat)
    private var showOverlay: Bool

    private let handleProfileTap: (() -> Void)

    public init(image: Binding<UIImage?>, profileImageUrl: String?,
                size: (width: CGFloat, height: CGFloat) = (106, 106),
                showOverlay: Bool = false, handleProfileTap: @escaping () -> Void) {
        self._image = image
        self.profileImageUrl = profileImageUrl
        self.size = size
        self.showOverlay = showOverlay
        self.handleProfileTap = handleProfileTap
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let urlString = profileImageUrl, let url = URL(string: urlString), image == nil {
                    Circle()
                        .background(
                            Circle()
                                .foregroundStyle(container2Color)
                        )
                        .frame(width: size.width, height: size.height, alignment: .center)

                    KFImage(url)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height, alignment: .center)
                        .clipShape(Circle())
                } else {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width, height: size.height, alignment: .center)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .strokeBorder(.clear, lineWidth: 0)
                            .background(
                                Circle()
                                    .foregroundStyle(container2Color)
                            )
                            .frame(width: size.width, height: size.height, alignment: .center)

                        Image(.user)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width, height: size.height, alignment: .center)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .overlay {
            if showOverlay {
                Image(.editPencilIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18, alignment: .center)
                    .padding(4)
                    .background(containerColor)
                    .clipShape(Circle())
                    .padding([.top, .leading], 52)
            }
        }
        .onTapGesture(perform: handleProfileTap)
    }
}
