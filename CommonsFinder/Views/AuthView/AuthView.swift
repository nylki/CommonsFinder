//
//  AuthView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 10.11.24.
//

import SwiftUI

struct AuthView: View {
    /// It is possible to either go to the onboardingChoice first or directly to login or register
    let initialDestination: AuthNavigationDestination

    var body: some View {
        NavigationStack {
            Group {
                switch initialDestination {
                case .onboardingChoice:
                    OnboardingView()
                case .login:
                    LoginView()
                case .register:
                    RegisterView()
                }
            }
            .navigationDestination(for: AuthNavigationDestination.self) { destination in
                switch destination {
                case .onboardingChoice:
                    OnboardingView()
                case .login:
                    LoginView()
                case .register:
                    RegisterView()
                }
            }

        }

    }
}

#Preview("Onboarding", traits: .previewEnvironment) {
    AuthView(initialDestination: .onboardingChoice)
}

#Preview("Login", traits: .previewEnvironment) {
    AuthView(initialDestination: .login)
}

#Preview("Register", traits: .previewEnvironment) {
    AuthView(initialDestination: .register)
}
