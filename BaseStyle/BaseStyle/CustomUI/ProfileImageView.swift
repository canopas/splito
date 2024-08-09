//
//  ProfileImageView.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 01/04/24.
//

import SwiftUI
import Kingfisher

public struct MemberProfileImageView: View {

    let imageUrl: String?
    let height: CGFloat

    public init(imageUrl: String?, height: CGFloat = 40) {
        self.imageUrl = imageUrl
        self.height = height
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let imageUrl, let url = URL(string: imageUrl) {
                KFImage(url)
                    .placeholder({ _ in
                        ImageLoaderView()
                    })
                    .setProcessor(ResizingImageProcessor(referenceSize: CGSize(width: (height * UIScreen.main.scale), height: (height * UIScreen.main.scale)), mode: .aspectFill))
                    .resizable()
                    .scaledToFill()
                    .frame(width: height, height: height, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: height / 2))
                    .overlay(
                        Circle()
                            .strokeBorder(Color.gray, lineWidth: 1)
                    )
            } else {
                Image(.user)
                    .resizable()
                    .scaledToFill()
                    .frame(width: height, height: height, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: height / 2))
                    .overlay(
                        Circle()
                            .strokeBorder(Color.gray, lineWidth: 1)
                    )
            }
        }
    }
}

public struct GroupProfileImageView: View {

    let imageUrl: String?
    let size: (width: CGFloat, height: CGFloat)

    public init(imageUrl: String?, size: (width: CGFloat, height: CGFloat) = (40, 40)) {
        self.imageUrl = imageUrl
        self.size = size
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let imageUrl, let url = URL(string: imageUrl) {
                KFImage(url)
                    .placeholder({ _ in
                        ImageLoaderView()
                    })
                    .setProcessor(ResizingImageProcessor(referenceSize: CGSize(width: (50 * UIScreen.main.scale), height: (50 * UIScreen.main.scale)), mode: .aspectFill))
                    .resizable()
            } else {
                Image(.group)
                    .resizable()
            }
        }
        .scaledToFill()
        .frame(width: size.width, height: size.height)
        .background(container2Color)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.trailing, 16)
    }
}
