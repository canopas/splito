//
//  HomeRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 26/02/24.
//

import Data
import BaseStyle
import SwiftUI

struct HomeRouteView: View {

    @State private var openExpenseSheet = false

    var body: some View {
        ZStack {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Friends", systemImage: "person")
                    }
                    .tag(0)

                GroupRouteView()
                    .tabItem {
                        Label("Groups", systemImage: "person.2")
                    }
                    .tag(1)

                InvisibleView()
                    .hidden()

                HomeView()
                    .tabItem {
                        Label("Activity", systemImage: "chart.line.uptrend.xyaxis.circle")
                    }
                    .tag(3)

                HomeView()
                    .tabItem {
                        Label("Account", systemImage: "person.crop.square")
                    }
                    .tag(4)
            }
            .tint(primaryColor)
            .overlay(
                CenterFabButton {
                    openExpenseSheet = true
                }
            )
            .fullScreenCover(isPresented: $openExpenseSheet) {
                ExpenseRouteView()
            }
        }
    }
}

struct InvisibleView: View {
    var body: some View {
        Color.clear // Invisible color
            .contentShape(Rectangle()) // Intercepts taps
            .allowsHitTesting(false) // Disables hit testing
            .disabled(true)
    }
}

struct CenterFabButton: View {

    var onclick: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

                Button {
                    onclick()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 43, height: 43)
                        .tint(primaryColor)
                        .background(backgroundColor)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .padding(.vertical, 1)

                Spacer()
            }
        }
    }
}
