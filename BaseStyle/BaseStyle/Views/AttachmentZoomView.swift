//
//  AttachmentZoomView.swift
//  Splito
//
//  Created by Amisha Italiya on 25/11/24.
//

import SwiftUI
import Kingfisher

// MARK: - AttachmentContainerView

public struct AttachmentContainerView: View {

    @Binding var showImageDisplayView: Bool

    var image: UIImage?
    var imageUrl: String?

    @Namespace private var animationNamespace

    public init(showImageDisplayView: Binding<Bool>, image: UIImage? = nil, imageUrl: String? = nil) {
        self._showImageDisplayView = showImageDisplayView
        self.image = image
        self.imageUrl = imageUrl
    }

    public var body: some View {
        HStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let imageUrl, let url = URL(string: imageUrl) {
                KFImage(url)
                    .placeholder { _ in
                        ImageLoaderView()
                    }
                    .setProcessor(DownsamplingImageProcessor(size: UIScreen.main.bounds.size)) // Downsample to fit screen size
                    .cacheMemoryOnly()
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
        .matchedGeometryEffect(id: "image", in: animationNamespace)
        .onTapGestureForced {
            showImageDisplayView = true
        }
    }
}

// MARK: - AttachmentZoomView

public struct AttachmentZoomView: View {
    @Environment(\.dismiss) var dismiss

    var image: UIImage?
    var imageUrl: String?

    @Namespace var animationNamespace

    public init(image: UIImage? = nil, imageUrl: String? = nil) {
        self.image = image
        self.imageUrl = imageUrl
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                if #available(iOS 18.0, *) {
                    ZoomableImageView(image: image, imageUrl: imageUrl, geometry: geometry)
                        .matchedGeometryEffect(id: "image", in: animationNamespace)
                        .navigationTransition(.zoom(sourceID: "zoom", in: animationNamespace))
                } else {
                    ZoomableImageView(image: image, imageUrl: imageUrl, geometry: geometry)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(disableText)
                }
            }
        }
    }
}
