//
//  FloatingGroupMenu.swift
//  Splito
//
//  Created by Amisha Italiya on 12/03/24.
//

import SwiftUI
import BaseStyle

struct FloatingAddGroupButton: View {

    @Binding var showMenu: Bool

    var showCreateMenu: Bool
    var joinGroupTapped: () -> Void
    var createGroupTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                VSpacer()

                ZStack(alignment: .trailing) {
                    Button {
                        joinGroupTapped()
                    } label: {
                        Text("Join Group")
                            .padding()
                            .font(.subTitle3())
                            .background(backgroundColor)
                            .foregroundStyle(primaryColor)
                            .overlay(RoundedRectangle(cornerRadius: 30).stroke(primaryColor, lineWidth: 1))
                    }
                    .offset(y: showMenu ? -60 : 0)
                    .opacity(showMenu ? 1 : 0)
                    .rotationEffect(.degrees(showMenu ? 0 : -180))

                    if showCreateMenu {
                        Button {
                            createGroupTapped()
                        } label: {
                            Text("Create Group")
                                .padding()
                                .font(.subTitle3())
                                .background(backgroundColor)
                                .foregroundStyle(primaryColor)
                                .overlay(RoundedRectangle(cornerRadius: 30).stroke(primaryColor, lineWidth: 1))
                        }
                        .offset(y: showMenu ? -120 : 0)
                        .opacity(showMenu ? 1 : 0)
                        .rotationEffect(.degrees(showMenu ? 0 : -180))
                    }

                    Button {
                        showMenu.toggle()
                    } label: {
                        Image(systemName: "plus")
                            .padding()
                            .font(.title3)
                            .rotationEffect(.degrees(showMenu ? 45 : 0))
                    }
                    .buttonStyle(.scale)
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.orange))
                }
                .animation(.easeInOut(duration: 0.4), value: showMenu)
            }
            .frame(maxWidth: isIpad ? 600 : .infinity, alignment: .bottomTrailing)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 16)
        .padding(.horizontal, 20)
    }
}
