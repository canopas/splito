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
        OnboardItem(image: .tracking, title: "Tracking", description: "keep track of balances between friends and loved ones."),
        OnboardItem(image: .expence, title: "Expences", description: "Add & split expences with groups or individuals."),
        OnboardItem(image: .payBack, title: "Pay Back", description: "Settle up and pay back your friends any time.")
    ]

    @ObservedObject var viewModel: OnboardViewModel

    public var body: some View {
        VStack(alignment: .center, spacing: 0) {
            GeometryReader { proxy in
                TabView(selection: $viewModel.currentPageIndex) {
                    ForEach(0..<onboardItems.count, id: \.self) { index in
                        OnboardPageView(index: index, items: onboardItems, proxy: proxy, onStartBtnTap: viewModel.loginAnonymous)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }

            Spacer()

			ZStack(alignment: .center) {
				PageControl(numberOfPages: onboardItems.count, currentIndex: $viewModel.currentPageIndex)
					.frame(height: 10)
					.padding(.horizontal, 16)

				HStack {
					Spacer()
					Button("Next") {
						withAnimation {
							viewModel.currentPageIndex += 1
						}
					}
                    .fontWeight(.semibold)
				}
				.padding(.horizontal, 30)
				.opacity(viewModel.currentPageIndex == (onboardItems.count - 1) ? 0 : 1)
			}

            VSpacer(30)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct OnboardPageView: View {

    var index: Int
    var items: [OnboardItem]
    let proxy: GeometryProxy

    var onStartBtnTap: (() -> Void)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .center, spacing: 10) {
                VSpacer(20)

                Image(items[index].image)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(primaryText)
                    .frame(width: 200, height: 200, alignment: .center)

                VSpacer(20)

                Text(items[index].title)
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(primaryText)

                Text(items[index].description)
                    .font(.title2)
                    .foregroundColor(secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                VSpacer(70)

                PrimaryButton(text: "Get Started", showLoader: false) {
                    onStartBtnTap()
                }
                .opacity(index == (items.count - 1) ? 1 : 0)

                VSpacer(20)
            }
            .frame(maxWidth: isIpad ? 600 : .infinity, minHeight: proxy.size.height, alignment: .center)
        }
        .padding(.horizontal, 20)
    }
}

public struct OnboardItem: Hashable {
    let image: ImageResource
    let title: String
    let description: String
}

#Preview {
    OnboardView(viewModel: OnboardViewModel())
}
