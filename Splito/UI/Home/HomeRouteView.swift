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

                HomeView()
                    .tabItem {
//                        Label("", systemImage: "plus.circle.fill")
                    }
                    .tag(1)

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
            .toolbarColorScheme(.light, for: .tabBar)

            CenterFabButton()
        }
    }
}

struct CenterFabButton: View {
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

                Button {
                    // Open screen
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
