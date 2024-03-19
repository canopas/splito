//
//  GroupSettingView.swift
//  Splito
//
//  Created by Amisha Italiya on 15/03/24.
//

import SwiftUI

struct GroupSettingView: View {

    @ObservedObject var viewModel: GroupSettingViewModel

    var body: some View {
        Text("Hello, World!")
    }
}

#Preview {
    GroupSettingView(viewModel: GroupSettingViewModel())
}
