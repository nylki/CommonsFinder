//
//  RegisterView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 10.11.24.
//

import CommonsAPI
import Nuke
import NukeUI
import RegexBuilder
import SwiftUI
import Vision
import os.log

struct RegisterView: View {
    @Environment(AccountModel.self) private var account
    @Environment(Navigation.self) private var navigation

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var email: String = ""
    @State private var captchaWord: String = ""
    @State private var captchaID: String = ""
    @State private var captchaURL: URL?
    @State private var token: String = ""

    @State private var usernameValidation: ValidationStatus?
    @State private var passwordValidation: ValidationStatus?
    @State private var emailValidation: ValidationStatus?
    @State private var captchaValidation: ValidationStatus?
    @State private var isValidating = false
    @State private var validationTask: Task<Void, Never>?

    @State private var isRegistering = false
    @State private var showAlert = false
    @State private var createAccountError: Authentication.AuthError?

    @FocusState private var focus: TextFieldKey?

    private let helpText = String(
        localized: """
            Unfortunately, wikimedia commons does not have an audio alternative available.
            Please contact the site administrators for assistance if this is unexpectedly preventing you from making legitimate posts at the Commons:Help desk. If you are giving a correct answer that is not being accepted, please provide details of the problem.
            """
    )


    private var allFieldsValid: Bool {
        if !isValidating, let usernameValidation, let passwordValidation, let emailValidation,
            usernameValidation.isValid, passwordValidation.isValid, emailValidation.isValid
        {
            true
        } else {
            false
        }
    }


    private func validate() {
        guard !username.isEmpty, !password.isEmpty, !email.isEmpty else {
            return
        }
        isValidating = true


        validationTask?.cancel()
        validationTask = Task<Void, Never> {
            try? await Task.sleep(for: .milliseconds(1000))
            guard !Task.isCancelled else { return }

            do {

                let validation = try await Authentication.validateUsernamePassword(username: username, password: password, email: email)

                usernameValidation = nil
                passwordValidation = nil
                emailValidation = nil

                // TODO: for message: use LocalizedError messages?
                switch validation {
                case .good:
                    usernameValidation = .init(status: .valid)

                    passwordValidation = .init(status: .valid)
                    emailValidation = .init(status: .valid)
                case .passwordTooLong:
                    passwordValidation = .init(status: .invalid, message: "Password is too long")
                case .passwordTooShort:
                    passwordValidation = .init(status: .invalid, message: "Password is too short")
                case .passwordContainsUsername:
                    passwordValidation = .init(status: .invalid, message: "Password must not contains you choosen username")
                case .passwordInvalid:
                    passwordValidation = .init(status: .invalid, message: "The Password is invalid")
                case .unknownInvalidation:
                    // TODO: post a proper error message?
                    logger.error("Failed to validate!")
                case .passwordInCommonList:
                    passwordValidation = .init(status: .invalid, message: "Password is too common and therefore considered insecure (found in the list of common passwords)", field: .password)
                case .passwordMissing:
                    passwordValidation = .init(status: .invalid, message: "Password is Empty")
                case .badUser:
                    usernameValidation = .init(status: .invalid, message: "Username contain characters that cannot be used. Do not use an email address as username.")
                case .userExists:
                    usernameValidation = .init(status: .invalid, message: "The Username is already taken")
                }
            } catch {
                logger.error("Failed to validate! \(error)")
            }

            let isValidEmail = ValidationUtils.isValidEmailAddress(string: email)
            if isValidEmail == false {
                emailValidation = .init(status: .invalid, message: "The email-address is not valid.")
            }

            // If everything above is valid so var, generate captcha and show it to user.
            if isValidEmail,
                passwordValidation?.isValid == true,
                emailValidation?.isValid == true,
                usernameValidation?.isValid == true
            {
                await fetchTokenAndCaptcha()
            }

            isValidating = false
        }
    }

    private func fetchTokenAndCaptcha() async {
        do {
            let info = try await Authentication.fetchCreateAccountTokenAndCaptchaInfo()
            captchaURL = info.captchaURL
            captchaID = info.captchaID
            token = info.token
        } catch {
            logger.error("Failed to get token and captcha info!")
        }
    }

    private var registerButtonDisabled: Bool {
        !allFieldsValid || isRegistering || isValidating
    }

    var body: some View {
        Form {
            usernameField
            passwordField

            emailField

            captchaView

            Button(action: register) {
                if isValidating {
                    Label {
                        Text("validating...")
                    } icon: {
                        ProgressView().progressViewStyle(.circular)
                    }
                } else if isRegistering {
                    Label {
                        Text("Creating Account...")
                    } icon: {
                        ProgressView().progressViewStyle(.circular)
                    }
                } else if allFieldsValid {
                    Label("Register", systemImage: "person.crop.circle")
                        .contentTransition(.symbolEffect)
                } else {
                    Label("Register", systemImage: "person.crop.circle")
                        .contentTransition(.symbolEffect)
                }
            }
            .contentTransition(.symbolEffect)
            .backgroundStyle(allFieldsValid ? Color.accentColor : Color.clear)
            .padding(.vertical)
            .disabled(registerButtonDisabled)

            #if !os(macOS)
                .textInputAutocapitalization(.never)
            #endif
            .disableAutocorrection(true)
            .animation(.default, value: isValidating)
            .animation(.default, value: usernameValidation)
            .animation(.default, value: passwordValidation)
            .animation(.default, value: emailValidation)
            .alert(isPresented: $showAlert, error: createAccountError) { _ in
                Button("OK") {
                    // some other was to handle this?
                }
            } message: { error in
                Text(error.recoverySuggestion ?? "Try again later.")
            }

        }
        .disabled(isRegistering)
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationTitle("Register at Wikimedia Commons")
        .onChange(of: username) { validate() }
        .onChange(of: password) { validate() }
        .onChange(of: email) { validate() }


    }

    @ViewBuilder
    private var usernameField: some View {
        lazy var isInvalid = usernameValidation?.isValid == false

        VStack {
            TextField("Username", text: $username)
                .focused($focus, equals: .username)
                .textContentType(.username)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit {
                    focus = .password
                }
                .textFieldStyle(
                    OutlinedTextFieldStyle(errorStyle: isInvalid, message: usernameValidation?.message)
                )

            //            if isInvalid, let message = usernameValidation?.message {
            //                fieldErrorText(message)
            //            }
        }

    }

    @ViewBuilder
    private var passwordField: some View {
        lazy var isInvalid = passwordValidation?.isValid == false

        VStack {
            // NOTE: Strong Password is not triggered if iCloud Keychain sharing disabled and/or there is no site-association. Either coordinate with Wikimedia to add the app to an apple-app-site-association file, or tell the user the save the password in their keychain?
            // https://en.wikipedia.org/.well-known/apple-app-site-association

            SecureField("Password", text: $password)
                .focused($focus, equals: .password)
                .textContentType(.newPassword)
                .autocorrectionDisabled()

                .submitLabel(.send)
                .onSubmit {
                    focus = .email
                }
                .textFieldStyle(
                    OutlinedTextFieldStyle(errorStyle: isInvalid, message: passwordValidation?.message)
                )
        }
    }

    @ViewBuilder
    private var emailField: some View {
        lazy var isInvalid = emailValidation?.isValid == false

        VStack {
            TextField("E-Mail Address", text: $email)
                .focused($focus, equals: .email)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .submitLabel(.next)
                .onSubmit {
                    if let emailValidation, emailValidation.isValid, captchaURL != nil {
                        focus = .captcha
                    }
                }
                .textFieldStyle(
                    OutlinedTextFieldStyle(
                        errorStyle: isInvalid,
                        message: emailValidation?.message
                    )
                )
        }

    }


    @ViewBuilder
    private var captchaView: some View {
        if let captchaURL {
            VStack {
                LazyImage(url: captchaURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            #if DEBUG
                                .onTapGesture {
                                    if let cgimage = phase.imageContainer?.image.cgImage {
                                        experimentalSolveCaptcha(cgimage: cgimage)
                                    }
                                }
                            #endif
                    } else {
                        Label {
                            Text("Loading captcha...")
                        } icon: {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }

                    }
                }
                .frame(height: 100)
                .help(helpText)


                lazy var isInvalid = captchaValidation?.isValid == false

                VStack {
                    TextField("Please enter the text seen above", text: $captchaWord)
                        .focused($focus, equals: .captcha)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .textFieldStyle(
                            OutlinedTextFieldStyle(errorStyle: isInvalid, message: captchaValidation?.message)
                        )
                }
            }
        } else {
            EmptyView()
        }
    }

    private func experimentalSolveCaptcha(cgimage: CGImage) {

        let paddingHorizontal = CGFloat(cgimage.width) / 7.0
        let cropped = cgimage.cropping(
            to: .init(
                x: paddingHorizontal,
                y: 0,
                width: CGFloat(cgimage.width) - paddingHorizontal,
                height: CGFloat(cgimage.height)

            ))

        guard let cropped else { return }

        // Create a new request to recognize text.

        Task {
            var request = RecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.automaticallyDetectsLanguage = true
            request.minimumTextHeightFraction = 0.6
            request.usesLanguageCorrection = true
            let handler = ImageRequestHandler(cropped)
            do {
                // Perform the text-recognition request.
                let result = try await handler.perform(request)

                let recognizedStrings = result.compactMap { observation in
                    // Return the string of the top VNRecognizedText instance.
                    return observation.topCandidates(1).first?.string
                }

                print(recognizedStrings.description)
                if let candidate = recognizedStrings.first(where: { $0.count > 3 }) {
                    captchaWord =
                        candidate
                        .folding(options: .diacriticInsensitive, locale: .init(identifier: "en"))
                        .lowercased()
                        .replacing(.word.inverted, with: "")
                }
            } catch {
                print("Unable to perform the requests: \(error).")
            }
        }

    }


    private func register() {
        guard allFieldsValid else { return }
        isRegistering = true

        Task<Void, Never> {
            defer { isRegistering = false }
            do {
                let user = try await account.createAccount(
                    username: username,
                    password: password,
                    email: email,
                    captchaWord: captchaWord,
                    captchaID: captchaID,
                    token: token
                )

                assert(user.username == username)
                navigation.dismissOnboarding()

            } catch Authentication.AuthError.captchaFailed {

                // Fetch a new captcha and tell the user that the captcha was not correct.
                await fetchTokenAndCaptcha()
                captchaWord = ""
                captchaValidation = .init(
                    status: .invalid,
                    message: "The text was not correct, please try again.",
                    field: .captcha
                )

            } catch let error as Authentication.AuthError {
                createAccountError = error
                showAlert = true
            } catch {
                assertionFailure("Unexpected error")
            }
        }

    }
}

private enum TextFieldKey: Equatable {
    case username
    case password
    case email
    case captcha
}

private struct ValidationStatus: Equatable {
    let status: Status

    let message: LocalizedStringResource?

    init(status: Status, message: LocalizedStringResource? = nil, field: TextFieldKey? = nil) {
        self.status = status
        self.message = message
    }

    var isValid: Bool {
        switch status {
        case .valid: true
        default: false
        }
    }

    enum Status: Equatable {
        case waiting
        case valid
        case invalid
        case error
    }
}


extension OutlinedTextFieldStyle {
    fileprivate init(errorStyle: Bool?, message: LocalizedStringResource?) {
        if errorStyle == true {
            self = .init(style: .error, message: message)
        } else {
            self = .init()
        }
    }
}


#Preview(traits: .previewEnvironment) {
    RegisterView()
}
