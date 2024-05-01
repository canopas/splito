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

    public init(imageUrl: String?, height: CGFloat = 50) {
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

    public init(imageUrl: String?) {
        self.imageUrl = imageUrl
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
                    .scaledToFill()
                    .frame(width: 50, height: 50, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(.group)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
