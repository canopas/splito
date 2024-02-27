//
//  HomeRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 26/02/24.
//

import Data
import SwiftUI

struct HomeRouteView: View {
    
    @Inject var appRouter: Router<AppRoute>
    
    public var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Menu", systemImage: "list.dash")
                }
            
            HomeView()
                .tabItem {
                    Label("Order", systemImage: "square.and.pencil")
                }
            
            HomeView()
                .tabItem {
                    Label("Menu", systemImage: "list.dash")
                }
        }
    }
}
