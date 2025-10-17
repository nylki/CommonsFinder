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
    @State private var isShowingUserDialog = false

    var body: some View {
        List {
            let tip = AccountTip()
            if account.activeUser == nil {
                TipView(tip, arrowEdge: .bottom)
            }
            if let activeUser = account.activeUser {
                Section {
                    Button {
                        isShowingUserDialog = true
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")

                            VStack(alignment: .leading) {
                                Text(activeUser.username)

                                Text("Wikimedia Account")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tint(.primary)
                        }
                    }
                    .confirmationDialog("User actions", isPresented: $isShowingUserDialog) {

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
                    .confirmationDialog("Are you sure you want to log-out ?", isPresented: $isShowingLogoutDialog, titleVisibility: .visible) {
                        Button("Logout User", systemImage: "square.and.arrow.up", role: .destructive, action: logout)

                        Button("Cancel", role: .cancel) {
                            isShowingLogoutDialog = false
                        }
                    }

                }
                .imageScale(.large)
                .animation(.default, value: account.activeUser)

            } else {
                Button {
                    tip.invalidate(reason: .actionPerformed)
                    navigation.openOnboarding()
                } label: {
                    Label("Add Account", systemImage: "person.crop.circle")
                        .bold()
                        .foregroundStyle(.white)
                }
                .listRowBackground(Color.accentColor)

            }


            Section("General") {
                Link(destination: URL(string: "https://github.com/nylki/CommonsFinder")!) {
                    Label("About", systemImage: "info.circle")
                }
                .foregroundStyle(.primary)
            }


            #if DEBUG
                Section {
                    NavigationLink(destination: PulseUI.ConsoleView.init()) {
                        Text("Console")
                    }
                }

            #endif

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
