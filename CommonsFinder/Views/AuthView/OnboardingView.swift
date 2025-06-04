//
//  OnboardingView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 10.11.24.
//

import SwiftUI
import TipKit

struct OnboardingView: View {
    var body: some View {
        VStack(alignment: .leading) {
            // NOTE: uses the nested navigation inside Authview
            // so don't use Navigation Environment.
            // TODO: maybe have specific AuthNavigation Observable


            NavigationLink(value: AuthNavigationDestination.login) {
                HStack {
                    Image(systemName: "key")
                    VStack(alignment: .leading) {
                        Text("Login")
                        Text("with existing account")
                            .font(.caption)
                    }
                    Spacer()
                }

            }
            NavigationLink(value: AuthNavigationDestination.register) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                    VStack(alignment: .leading) {
                        Text("Register")
                        Text("new account")
                            .font(.caption)
                    }
                    Spacer()
                }
            }

            Spacer()
        }
        .buttonStyle(ExpandingButtonStyle())
        .scenePadding(.horizontal)
        .navigationTitle("Wikimedia Account")
        .navigationBarTitleDisplayMode(.inline)
        .presentationDetents([.fraction(0.33), .large])
    }
}

#Preview(traits: .previewEnvironment) {
    OnboardingView()
}
