//
//  OnboardView.swift
//  Splito
//
//  Created by Amisha Italiya on 12/02/24.
//

import BaseStyle
import SwiftUI
import Data

struct OnboardView: View {

    var onboardItems: [OnboardItem] = [
        OnboardItem(title: "Split your expenses between friends and colleagues with ease!"),
        OnboardItem(image: .addExpenses, title: "Let's add expenses!", subtitle: "Let's add an expense to get you started splitting bills with your friends!"),
        OnboardItem(image: .settleUpBills, title: "Settle up bills together!", subtitle: "Time to settle up! Track shared expenses and split them in seconds.", description: "Use settle up to divide costs with your friends or colleagues. It's easy and ensures everyone pays or receives their fair share.\n\nLet's get started splitting bills easily with friends.")
    ]

    @StateObject var viewModel: OnboardViewModel

    public var body: some View {
        VStack(spacing: 0) {
            VSpacer(40)

            GeometryReader { proxy in
                TabView(selection: $viewModel.currentPageIndex) {
                    ForEach(0..<onboardItems.count, id: \.self) { index in
                        OnboardPageView(index: index, items: onboardItems, proxy: proxy)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .onChange(of: viewModel.currentPageIndex) { newIndex in
                    viewModel.handleGetStartedBtnVisibility(isLastIndex: newIndex == onboardItems.count - 1)
                }
            }

            if viewModel.showGetStartedButton {
                PrimaryButton(text: "Get Started", onClick: viewModel.handleGetStartedAction)
                    .padding(.top, 8)
                    .padding(.horizontal, 16)

                VSpacer(32)
            }

            ZStack(alignment: .center) {
                PageControl(numberOfPages: onboardItems.count, currentIndex: $viewModel.currentPageIndex)
                    .frame(height: 10)
                    .padding(.top, viewModel.currentPageIndex == onboardItems.count - 1 ? 0 : 8)
                    .padding([.horizontal, .bottom], 16)
                    .animation(.easeInOut, value: viewModel.currentPageIndex)
            }
        }
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(surfaceColor)
    }
}

struct OnboardPageView: View {

    var index: Int
    var items: [OnboardItem]
    let proxy: GeometryProxy

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(items[index].title.localized)
                    .font(.Header1())
                    .foregroundStyle(primaryText)
                    .padding(.horizontal, 16)

                if let subtitle = items[index].subtitle {
                    VSpacer(16)

                    Text(subtitle.localized)
                        .font(.subTitle1())
                        .foregroundStyle(disableText)
                        .lineSpacing(4)
                        .tracking(-0.2)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 16)
                }

                VSpacer((index == 1) ? 60 : 40)

                if let image = items[index].image {
                    Image(image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: proxy.size.width, height: (index == 1) ? 420 : 225, alignment: .center)
                } else {
                    FirstIndexImageView(image: .schoolBuddies, width: 180, height: 180)
                    FirstIndexImageView(image: .colleagues, width: 200, height: 230, yOffset: -70, alignment: .leading)
                    FirstIndexImageView(image: .roomies, width: 200, height: 200, yOffset: -130)
                }

                if let description = items[index].description {
                    VSpacer(40)

                    Text(description.localized)
                        .font(.subTitle1())
                        .foregroundStyle(disableText)
                        .lineSpacing(4)
                        .tracking(-0.2)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: isIpad ? 600 : .infinity, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }
}

struct FirstIndexImageView: View {

    var image: ImageResource
    var width: CGFloat
    var height: CGFloat
    var yOffset: CGFloat = 0
    var alignment: Alignment = .trailing

    var body: some View {
        Image(image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: height)
            .offset(y: yOffset)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

public struct OnboardItem: Hashable {
    var image: ImageResource?
    let title: String
    var subtitle: String?
    var description: String?
}
