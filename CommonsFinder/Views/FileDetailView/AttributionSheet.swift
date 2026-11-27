//
//  AttributionSheet.swift
//  CommonsFinder
//
//  Created by Tom on 23.11.26.
//

import SwiftUI

struct AttributionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let mediaFile: MediaFile

    @State private var selectedCreditLineFormat = CreditLineCopyBox.CreditFormat.plain

    @State private var plainCreditLine: String?
    @State private var htmlCreditLine: String?

    @State private var didCopyCreditLineViaToolbar = 0


    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading) {
                    licenseNameTitle
                        .padding(.bottom, 5)

                    UsageTermsBox(mediaFile: mediaFile)

                    if let plainCreditLine, let htmlCreditLine {
                        CreditLineCopyBox(
                            plainCreditLine: plainCreditLine,
                            htmlCreditLine: htmlCreditLine,
                            isAttributionOptional: mediaFile.attributionRequiredWithFallback == false,
                            selectedFormat: $selectedCreditLineFormat
                        )
                    }


                    Spacer(minLength: 0)
                }
                .animation(.linear, value: plainCreditLine)
                .animation(.linear, value: htmlCreditLine)
            }
            .padding(.horizontal)
            .navigationTitle("Credit & License")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
            .task {
                plainCreditLine = await mediaFile.generatePlainTextCreditLine()
                htmlCreditLine = await mediaFile.generateHtmlCreditLine()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .title) {
                    Label("Credit & License", systemImage: "scroll")
                        .labelStyle(.titleAndIcon)
                }


                ToolbarItem {
                    Menu("more", systemImage: "ellipsis") {

                        if let plainCreditLine, let htmlCreditLine {
                            Menu {
                                ShareLink(item: plainCreditLine) {
                                    Label("plain text", systemImage: "paragraphsign")
                                }
                                ShareLink(item: htmlCreditLine) {
                                    Label("HTML", systemImage: "chevron.left.forwardslash.chevron.right")
                                }
                            } label: {
                                Label("Share credit line", systemImage: "square.and.arrow.up.on.square")
                            }
                            Menu {
                                Button {
                                    UIPasteboard.general.string = plainCreditLine
                                    didCopyCreditLineViaToolbar += 1
                                    AccessibilityNotification.Announcement("Credit line copied").post()

                                } label: {
                                    Label("plain text", systemImage: "paragraphsign")
                                }

                                Button {
                                    UIPasteboard.general.string = htmlCreditLine
                                    didCopyCreditLineViaToolbar += 1
                                    AccessibilityNotification.Announcement("Credit line copied").post()
                                } label: {
                                    Label("HTML", systemImage: "chevron.left.forwardslash.chevron.right")
                                }
                            } label: {
                                Label("Copy credit line", systemImage: "document.on.document")
                            }
                        }

                        Divider()

                        if let licenseURL = mediaFile.licenseURL {
                            Link(destination: licenseURL) {
                                Label("Read full license", systemImage: "text.document")
                                if let host = licenseURL.host() {
                                    Text(host)
                                }
                            }
                        }


                        // TODO: parse url from author

                        //                            Button("Open Author's Page", systemImage: "square.and.arrow.up.on.square") {
                        //
                        //                            }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var licenseNameTitle: some View {
        VStack(alignment: .leading) {
            Text(mediaFile.licenseShortName ?? "Unknown")
                .fontWeight(.medium)

            Group {
                if let usageTerms = mediaFile.usageTerms,
                    usageTerms != mediaFile.licenseShortName
                {
                    Text(usageTerms)

                } else if mediaFile.licenseGroup == .pd {
                    Text("No known copyright restrictions")

                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct UsageTermsBox: View {
    let mediaFile: MediaFile

    var body: some View {

        switch mediaFile.licenseGroup {
        case .cc0:
            ccZeroView
        case .ccBy, .ccBySa:
            ccByView
        case .pd:
            publicDomainView
        default:
            otherLicenseView
        }
    }

    @ViewBuilder
    private var ccByView: some View {
        Text("Your are free to:")
            .bold()
            .foregroundStyle(.secondary)
        GroupBox {

            VStack(alignment: .leading) {
                TermsCheckBoxLine(
                    title: Text("Share"),
                    caption: Text(
                        "Copy and redistribute the material in any medium or format for any purpose, even commercially."
                    ),
                    icon: Image(systemName: "checkmark").foregroundStyle(.green)
                )
                Divider()

                TermsCheckBoxLine(
                    title: Text("Adapt"),
                    caption: Text("remix, transform, and build upon the material for any purpose, even commercially."),
                    icon: Image(systemName: "checkmark").foregroundStyle(.green)
                )

            }
        }

        Text("Under the following conditions:")
            .bold()
            .foregroundStyle(.secondary)

        GroupBox {
            VStack(alignment: .leading) {
                attributionRequiredBox


                Divider()

                if mediaFile.licenseGroup == .ccBySa {
                    TermsCheckBoxLine(
                        title: Text("Share Alike"),
                        caption: Text("If you remix, transform, or build upon the material, you must distribute your contributions under the same or compatible license as the original."),
                        icon: Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                    )
                }

            }
        }

        GroupBox {
            fullLicenseLink
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }

    }

    @ViewBuilder
    private var ccZeroView: some View {
        GroupBox {

            VStack(alignment: .leading) {
                TermsCheckBoxLine(
                    title: Text("No Copyright"),
                    caption: Text(
                        "The person who associated a work with this deed has dedicated the work to the public domain by waiving all of his or her rights to the work worldwide under copyright law, including all related and neighboring rights, to the extent allowed by law. "
                    ),
                    icon: Image(systemName: "checkmark").foregroundStyle(.green)
                )
                TermsCheckBoxLine(
                    title: Text("Share & Adapt"),
                    caption: Text("You can copy, modify, distribute and perform the work, even for commercial purposes, all without asking permission. See Other Information below. "),
                    icon: Image(systemName: "checkmark").foregroundStyle(.green)
                )

                Divider()
                fullLicenseLink
            }
        }
    }

    @ViewBuilder
    private var publicDomainView: some View {
        GroupBox {
            attributionRequiredBox
            Divider()
            fullLicenseLink
        }
    }

    @ViewBuilder
    private var otherLicenseView: some View {
        GroupBox {
            attributionRequiredBox
            Divider()
            fullLicenseLink
        }
    }

    private var attributionRequiredBox: some View {
        if let attributionRequired = mediaFile.attributionRequiredWithFallback {
            if attributionRequired {
                TermsCheckBoxLine(
                    title: Text("Attribution"),
                    caption: Text(
                        "You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use."
                    ),
                    icon: Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                )
            } else {
                TermsCheckBoxLine(
                    title: Text("Credit optional"),
                    caption: Text("Not required, but naming the author and source is good practice."),
                    icon: Image(systemName: "checkmark").foregroundStyle(.green)
                )
            }
        } else {
            TermsCheckBoxLine(
                title: Text("Credit may be required"),
                caption: Text(""),
                icon: Image(systemName: "questionmark").foregroundStyle(.green)
            )
        }
    }

    private var fullLicenseLink: some View {
        if let licenseURL = mediaFile.licenseURL {
            Link(destination: licenseURL) {
                Label("Read full license", systemImage: "text.document")
            }
        } else {
            Link(destination: mediaFile.descriptionUrlLicenseSection) {
                Label("Read licensing details on Commons", systemImage: "text.document")
            }
        }
    }
}

private struct TermsCheckBoxLine<Icon: View>: View {

    let title: Text
    let caption: Text
    let icon: Icon

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                title
                    .fontWeight(.semibold)
                caption
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        } icon: {
            icon
        }
        .textSelection(.enabled)
    }
}

private struct CreditLineCopyBox: View {
    let plainCreditLine: String
    let htmlCreditLine: String
    let isAttributionOptional: Bool
    @Binding var selectedFormat: CreditFormat

    enum CreditFormat {
        case plain
        case html
    }


    @State private var didCopyPlainCreditLine = 0
    @State private var didCopyHtmlCreditLine = 0

    private var selectedCreditLineText: String {
        switch selectedFormat {
        case .plain: plainCreditLine
        case .html: htmlCreditLine
        }
    }

    private var didCopySelectedCreditLine: Int {
        switch selectedFormat {
        case .plain: didCopyPlainCreditLine
        case .html: didCopyHtmlCreditLine
        }
    }

    func onCopyCreditLine() {
        switch selectedFormat {
        case .plain:
            UIPasteboard.general.string = plainCreditLine
            didCopyPlainCreditLine += 1
        case .html:
            UIPasteboard.general.string = htmlCreditLine
            didCopyHtmlCreditLine += 1
        }

        AccessibilityNotification.Announcement("Credit line copied").post()
    }

    var body: some View {
        VStack(alignment: .leading) {

            HStack {
                Text("Credit line").fontWeight(.semibold)
                if isAttributionOptional {
                    Text("optional")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 7)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 5))
                }
                Spacer(minLength: 0)
            }
            Picker("Format", selection: $selectedFormat) {
                Text("Text").tag(CreditFormat.plain)
                Text("HTML").tag(CreditFormat.html)
            }
            .pickerStyle(.segmented)

            GroupBox {
                Text(selectedCreditLineText)
                    .textSelection(.enabled)
                    .monospaced()
                    .frame(minWidth: 0, maxWidth: .infinity)


                Button(action: onCopyCreditLine) {
                    Label(
                        didCopySelectedCreditLine != 0 ? "Copied" : "Copy credit line",
                        systemImage: didCopySelectedCreditLine != 0 ? "checkmark" : "document.on.document"
                    )
                    .contentTransition(.symbolEffect)
                    .frame(minWidth: 0, maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .sensoryFeedback(.impact(weight: .light), trigger: didCopyPlainCreditLine)
                .sensoryFeedback(.impact(weight: .light), trigger: didCopyHtmlCreditLine)

            }
        }
    }
}

#Preview(traits: .previewEnvironment) {
    Color.clear.sheet(isPresented: .constant(true)) {
        AttributionSheet(mediaFile: .makeRandomUploaded(id: "1", .horizontalImage))
    }
}
