//
//  LoginView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 10.11.24.
//

import SwiftUI

struct LoginView: View {
    @Environment(AccountModel.self) private var account
    @Environment(Navigation.self) private var navigation

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isPerformingLogin = false

    @State private var showAlert = false
    @State private var loginError: LoginFailure?
    @FocusState private var focus: FocusElement?

    private var requiredFieldsMissing: Bool {
        username.isEmpty || password.isEmpty
    }

    private enum FocusElement: Hashable {
        case username
        case password
    }

    var body: some View {
        ZStack {
            VStack {
                if isPerformingLogin {

                    Text("Logging in as \(username)")

                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    TextField("Username", text: $username)
                        .focused($focus, equals: .username)
                        .textContentType(.username)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }

                    SecureField("Password", text: $password)
                        .focused($focus, equals: .password)
                        .textContentType(.password)
                        .submitLabel(.send)
                        .onSubmit(login)

                    Button(action: login) {
                        Label("Login", systemImage: "key.horizontal")
                    }
                    .buttonStyle(ExpandingButtonStyle())
                    .disabled(requiredFieldsMissing || isPerformingLogin)
                }

            }
            .textFieldStyle(OutlinedTextFieldStyle())
            #if !os(macOS)
                .textInputAutocapitalization(.never)
            #endif
            .disableAutocorrection(true)
            .padding()
        }
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationTitle("Login to Wikimedia Commons")
        .animation(.bouncy, value: isPerformingLogin)
        .alert(isPresented: $showAlert, error: loginError) { _ in
            Button("OK") {
                // Handle acknowledgement.
            }
        } message: { error in
            Text(error.recoverySuggestion ?? "Try again later.")
        }
        .onAppear {
            focus = .username
        }
    }

    private func login() {
        Task<Void, Never> {
            isPerformingLogin = true
            defer { isPerformingLogin = false }
            do {
                try await account.login(username: username, password: password)
                navigation.dismissOnboarding()
            } catch let error as LoginFailure {
                loginError = error
                showAlert = true
            } catch {
                assertionFailure("Unexpected error type during logion \(error)")
            }
        }
    }
}

#Preview(traits: .previewEnvironment) {
    LoginView()
}
