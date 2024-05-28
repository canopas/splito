//
//  MainRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 16/02/24.
//

import Data
import BaseStyle
import SwiftUI

public struct MainRouteView: View {

    @Inject var preference: SplitoPreference

    @StateObject var viewModel = MainRouteViewModel()

    init() {
        Font.loadFonts()
    }

    public var body: some View {
        if viewModel.showOnboardFlow {
            OnboardRouteView()
        } else {
            HomeRouteView()
        }
    }
}
