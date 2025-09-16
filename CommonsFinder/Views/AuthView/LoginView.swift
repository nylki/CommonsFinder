//
//  LoginView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 10.11.24.
//

import SwiftUI

@Observable private final class LoginViewModel {
    var username: String = ""
    var password: String = ""
    var oneTimeCode: OneTimeCode = .empty

    var isPerformingLogin = false
    var loginState: LoginState = .usernameAndPassword

    var showAlert = false
    var loginError: Authentication.AuthError?

    var requiredFieldsMissing: Bool {
        username.isEmpty || password.isEmpty
    }

    enum LoginState: Equatable, Hashable {
        case usernameAndPassword
        case oneTimeCode
    }
}

extension OneTimeCode.CodeType {
    var title: LocalizedStringKey {
        switch self {
        case .twoFactor:
            "Two-factor token or recovery code"
        case .email:
            "Email-Code"
        }
    }
    var hintText: LocalizedStringKey {
        switch self {
        case .twoFactor:
            "Please enter a code from your two-factor authentication application to continue."
        case .email:
            "Please enter the one-time verification code sent by email to continue."
        }
    }
}

struct LoginView: View {
    @Environment(AccountModel.self) private var account
    @Environment(Navigation.self) private var navigation

    @State private var model = LoginViewModel()
    @State private var oneTimeCodeSelection: TextSelection?
    @FocusState private var focus: FocusElement?

    private enum FocusElement: Hashable {
        case username
        case password
        case oneTimeCode
    }

    var body: some View {

        VStack {

            Form {
                switch model.loginState {
                case .usernameAndPassword:
                    TextField("Username", text: $model.username)
                        .focused($focus, equals: .username)
                        .textContentType(.username)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }

                    SecureField("Password", text: $model.password)
                        .focused($focus, equals: .password)
                        .textContentType(.password)
                        .submitLabel(.send)
                        .onSubmit(login)

                    if model.isPerformingLogin {
                        HStack {
                            Text("logging in...")
                            ProgressView()
                                .progressViewStyle(.circular)
                        }


                    } else {
                        Button(action: login) {
                            Label("Login", systemImage: "key.horizontal")
                        }
                        .disabled(model.requiredFieldsMissing)
                    }


                case .oneTimeCode:
                    let codeType = model.oneTimeCode.type
                    Text(codeType.hintText)
                        .multilineTextAlignment(.leading)

                    TextField(codeType.title, text: $model.oneTimeCode.baseValue)
                        .focused($focus, equals: .oneTimeCode)
                        .textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .submitLabel(.next)
                        .onSubmit(login)

                    Button("Continue", action: login)
                        .disabled(model.oneTimeCode.isEmpty)
                }
            }
        }
        .buttonStyle(.glass)
        .animation(.default, value: model.isPerformingLogin)
        //            .textFieldStyle(OutlinedTextFieldStyle())
        #if !os(macOS)
            .textInputAutocapitalization(.never)
        #endif
        .disableAutocorrection(true)

        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationTitle("Login to Wikimedia Commons")
        .animation(.bouncy, value: model.loginState)
        .alert(isPresented: $model.showAlert, error: model.loginError) { _ in
            Button("OK") {
                if let error = model.loginError {
                    if case .twoFactorCodeFailed = error {
                        model.oneTimeCode.baseValue = ""
                        focus = .oneTimeCode
                    }
                }
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
            model.isPerformingLogin = true
            defer { model.isPerformingLogin = false }

            do {
                let result = try await account.login(
                    username: model.username,
                    password: model.password,
                    oneTimeCode: model.oneTimeCode
                )
                switch result {
                case .emailCodeRequired:
                    model.loginState = .oneTimeCode
                    model.oneTimeCode.type = .email
                case .twoFactorCodeRequired:
                    model.loginState = .oneTimeCode
                    model.oneTimeCode.type = .twoFactor
                case .loggedIn(let user):
                    navigation.dismissOnboarding()
                }
            } catch let error as Authentication.AuthError {
                model.loginError = error
                model.showAlert = true
            } catch {
                assertionFailure("Undefined error \(error)")
                model.showAlert = true
            }
        }
    }
}

#Preview(traits: .previewEnvironment) {
    Color.clear.sheet(isPresented: .constant(true)) {
        NavigationStack {
            LoginView()

        }

    }
}
