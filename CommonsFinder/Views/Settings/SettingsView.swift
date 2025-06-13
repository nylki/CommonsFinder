//
//  SettingsView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 03.10.24.
//

import CommonsAPI
import SwiftUI
import TipKit
import os.log

#if DEBUG
    import Pulse
    import PulseUI
#endif

struct SettingsView: View {
    @Environment(Navigation.self) private var navigation
    @Environment(AccountModel.self) private var account

    @State private var isShowingLogoutDialog = false

    var body: some View {
        ScrollView(.vertical) {
            VStack {
                Group {
                    if let activeUser = account.activeUser {
                        Menu(activeUser.username, systemImage: "person.crop.circle.fill") {
                            if let userPage = activeUser.userPage {
                                Link(destination: userPage) {
                                    Label("Open Profile", systemImage: "safari")
                                }
                            }
                            Button(
                                "Logout",
                                systemImage: "rectangle.portrait.and.arrow.forward",
                                role: .destructive,
                                action: { isShowingLogoutDialog = true }
                            )
                        }
                        .buttonStyle(ExpandingButtonStyle())
                        .confirmationDialog("Are you sure you want to log-out ?", isPresented: $isShowingLogoutDialog, titleVisibility: .visible) {
                            Button("Logout User", systemImage: "square.and.arrow.up", role: .destructive, action: logout)

                            Button("Cancel", role: .cancel) {
                                isShowingLogoutDialog = false
                            }
                        }
                    } else {
                        TipView(AccountTip(), arrowEdge: .bottom)
                        Button(action: navigation.openOnboarding) {
                            Label("Add Account", systemImage: "person.crop.circle")
                        }
                        .buttonStyle(ExpandingButtonStyle())
                    }
                }


                #if DEBUG
                    NavigationLink(destination: PulseUI.ConsoleView.init()) {
                        Text("Console")
                    }
                #endif

                Spacer()
            }
            .animation(.default, value: account.activeUser)
            .padding()

        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.automatic)

    }

    private func logout() {
        do {
            try account.logout()
        } catch {
            logger.fault("failed to logout user: \(error)")
        }
    }
}

struct AuthButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(.quaternary, in: .rect(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}


#Preview("Not Logged In", traits: .previewEnvironment) {
    SettingsView()
}

#Preview("Logged In", traits: .previewEnvironment) {
    SettingsView()
        .environment(AccountModel(appDatabase: .empty(), withTestUser: User(username: "LoremUser123")))
}
