//
//  ZoomableImageView.swift
//  BaseStyle
//
//  Created by Amisha Italiya on 28/11/24.
//

import SwiftUI
import Kingfisher

// MARK: - ZoomableImageView

public struct ZoomableImageView: View {

    var image: UIImage?
    var imageUrl: String?
    let geometry: GeometryProxy

    @State var scale: CGFloat = 1
    @State var scaleAnchor: UnitPoint = .center
    @State var lastScale: CGFloat = 1

    @State var offset: CGSize = .zero
    @State var lastOffset: CGSize = .zero

    @State var loadedImage: UIImage = UIImage()

    // MagnificationGesture for zooming (pinch-to-zoom)
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { gesture in
                scaleAnchor = .center  // Keep the zoom centered
                scale = lastScale * gesture
            }
            .onEnded { _ in
                fixOffsetAndScale(geometry: geometry)
            }
    }

    // DragGesture for panning (drag-to-move)
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { gesture in
                var newOffset = lastOffset
                newOffset.width += gesture.translation.width
                newOffset.height += gesture.translation.height
                offset = newOffset
            }
            .onEnded { _ in
                fixOffsetAndScale(geometry: geometry)
            }
    }

    public init(image: UIImage? = nil, imageUrl: String? = nil, geometry: GeometryProxy) {
        self.image = image
        self.imageUrl = imageUrl
        self.geometry = geometry
        if let image {
            self._loadedImage = State(initialValue: image)
        }
    }

    public var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .scaleEffect(scale, anchor: scaleAnchor)
                    .offset(offset)
                    .animation(.spring(), value: offset)
                    .animation(.spring(), value: scale)
                    .gesture(dragGesture)
                    .gesture(magnificationGesture)
                    .simultaneousGesture(TapGesture(count: 2).onEnded({ _ in
                        resetZoom()
                    }))
            } else if let imageUrl, let url = URL(string: imageUrl) {
                KFImage(url)
                    .placeholder { _ in
                        ImageLoaderView()
                    }
                    .setProcessor(DownsamplingImageProcessor(size: UIScreen.main.bounds.size))
                    .cacheMemoryOnly()
                    .onSuccess { result in
                        loadedImage = result.image
                    }
                    .resizable()
                    .scaledToFit()
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)  // Center the image in the available space
                    .scaleEffect(scale, anchor: scaleAnchor)  // Apply zoom scale effect
                    .offset(offset)  // Apply pan offset
                    .animation(.spring(), value: offset)  // Animate the offset change with a spring animation
                    .animation(.spring(), value: scale)  // Animate the scale change with a spring animation
                    .gesture(dragGesture)  // Attach the drag gesture to allow panning
                    .gesture(magnificationGesture)  // Attach the magnification gesture for zooming
                    .simultaneousGesture(TapGesture(count: 2).onEnded({ _ in
                        resetZoom()
                    }))
            }
        }
    }

    private func resetZoom() {
        scale = lastScale > 1 ? 1 : 3  // Toggle between reset scale (1) and zoom-in scale (3)
        offset = .zero  // Reset the offset to center the image
        scaleAnchor = .center  // Keep zooming centered
        lastScale = scale  // Store the new scale as the last scale
        lastOffset = .zero  // Reset the offset to zero
    }

    // Adjust the offset and scale to ensure the image stays within bounds
    private func fixOffsetAndScale(geometry: GeometryProxy) {
        let newScale: CGFloat = .minimum(.maximum(scale, 1), 4)  // Ensure the scale is between 1x and 4x
        let screenSize = geometry.size

        // Determine the original scale based on the aspect ratio of the image
        let originalScale = loadedImage.size.width / loadedImage.size.height >= screenSize.width / screenSize.height ?
        geometry.size.width / loadedImage.size.width :
        geometry.size.height / loadedImage.size.height

        let imageWidth = (loadedImage.size.width * originalScale) * newScale
        let imageHeight = (loadedImage.size.height * originalScale) * newScale
        var width: CGFloat = .zero
        var height: CGFloat = .zero

        if imageWidth > screenSize.width {
            let widthLimit: CGFloat = imageWidth > screenSize.width ? (imageWidth - screenSize.width) / 2 : 0
            width = offset.width > 0 ? .minimum(widthLimit, offset.width) : .maximum(-widthLimit, offset.width)
        }

        if imageHeight > screenSize.height {
            let heightLimit: CGFloat = imageHeight > screenSize.height ? (imageHeight - screenSize.height) / 2 : 0
            height = offset.height > 0 ? .minimum(heightLimit, offset.height) : .maximum(-heightLimit, offset.height)
        }

        let newOffset = CGSize(width: width, height: height)

        lastScale = newScale
        lastOffset = newOffset
        offset = newOffset
        scale = newScale
    }
}
