//
//  AttributionDetailView.swift
//  CommonsFinder
//
//  Created by Tom on 12.11.26.
//

import CommonsAPI
import SwiftUI

struct AttributionDetailView: View {
    let mediaFile: MediaFile

    @Environment(Navigation.self) private var navigation

    @State private var isShowingDetailsSheet = false
    @State private var isShowingAuthorUploaderPopover = false

    private var authorRawString: String? {
        return if let authorRaw = mediaFile.authorRaw {
            if let attributedString = AttributedStringCache.shared[authorRaw] {
                String(attributedString.characters)
            } else {
                mediaFile.authorRaw
            }
        } else {
            "Unknown"
        }
    }

    var isFileCreatedByUploader: Bool {

        if let sourceWikidataID = mediaFile.sourceWikidataID {
            // TODO: better use "tagged" typo for easier access to these values
            // originalCreationByUploader http://www.wikidata.org/entity/Q66458942
            if sourceWikidataID == "Q66458942" { return true }
        }

        if let sourceTextRaw = mediaFile.sourceTextRaw {
            if sourceTextRaw.contains("int-own-work") || sourceTextRaw.contains("own work") || sourceTextRaw.contains("self-photographed") {
                return true
            }
        }

        if let authorRawString {
            let rawAuthorUsernameMatches = authorRawString.trimmingCharacters(in: .whitespaces) == mediaFile.username

            if rawAuthorUsernameMatches {
                return true
            }
        }

        return false
    }

    private var parsedWikitextDate: Date? {
        guard let parsedWikitextDateString = mediaFile.parsedWikitextDateString else { return nil }

        if let dateParsedWithTime = try? Date(parsedWikitextDateString, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: false).dateSeparator(.dash)) {
            return dateParsedWithTime
        } else if let dateParsed = try? Date(parsedWikitextDateString, strategy: .iso8601.year().month().day().dateSeparator(.dash)) {
            return dateParsed
        } else {
            return nil
        }
    }


    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Text("License & Attribution")
                    .font(.headline)

                VStack(alignment: .leading) {

                    Button {
                        if isFileCreatedByUploader {
                            isShowingAuthorUploaderPopover = true
                        } else {
                            isShowingDetailsSheet = true
                        }

                    } label: {
                        AuthorLineLabel(
                            url: nil,
                            name: authorRawString,
                            isFileCreatedByUploader: isFileCreatedByUploader
                        )
                    }
                    .popover(isPresented: $isShowingAuthorUploaderPopover) {
                        VStack {
                            Button("Show attribution details") {
                                isShowingAuthorUploaderPopover = false
                                isShowingDetailsSheet = true
                            }

                            Button("Show more uploads by \(mediaFile.username)") {
                                isShowingAuthorUploaderPopover = false
                                navigation.openUserUploads(username: mediaFile.username)
                            }


                        }
                        .buttonBorderShape(.capsule)
                        .padding()
                        .presentationCompactAdaptation(.popover)

                    }

                    dateOriginalLine


                    Divider()
                        .padding(.vertical, 3)

                    if isFileCreatedByUploader {
                        uploadedDateLine
                    }
                    licenseLine
                    sourceLine

                }
                .accentColor(.primary)
                .padding()
                .background(.regularMaterial, in: .rect(cornerRadius: 16))
            }

            if !isFileCreatedByUploader {
                VStack(alignment: .leading) {
                    NavigationLink(value: NavigationStackItem.userUploads(username: mediaFile.username)) {
                        UploaderLineLabel(username: mediaFile.username)
                    }

                    uploadedDateLine

                }
                .accentColor(.primary)
                .padding()
                .background(.regularMaterial, in: .rect(cornerRadius: 16))
            }
        }


        .sheet(isPresented: $isShowingDetailsSheet) {
            Color.orange
        }


    }


    private var sourceLine: some View {
        SourceLine(
            isFileCreatedByUploader: isFileCreatedByUploader,
            sourceTextRaw: mediaFile.sourceTextRaw,
            sourceWikidataID: mediaFile.sourceWikidataID
        )
    }


    @ViewBuilder
    private var licenseLine: some View {

        let licenseIcon = Text("CC").monospaced().font(.callout).fontWeight(.semibold)
        let licenseText = Text(mediaFile.licenseShortName ?? mediaFile.licenseRaw ?? "Unknown License")

        Button {
            isShowingDetailsSheet = true
        } label: {
            AttributionRow(
                leadingIcon: licenseIcon,
                trailingIcon: Image(systemName: "info.circle"),
                mainText: licenseText,
                caption: Text("Some optional explanation short")
            )
        }
    }

    @ViewBuilder
    private var dateOriginalLine: some View {
        let originalDate = mediaFile.dateTimeWikibase
        let parsedWikitextDateString = mediaFile.parsedWikitextDateString

        let preciseDate = originalDate?.preciseDate ?? parsedWikitextDate

        let dateText: Text =
            if let preciseDate {
                Text(preciseDate, style: .date)
            } else if let localizedFormattedString = originalDate?.localizedFormattedString {
                Text(localizedFormattedString)
            } else if let parsedWikitextDateString {
                Text(parsedWikitextDateString)
            } else {
                Text("Unknown date")
            }

        let captionText =
            if let preciseDate {
                Text("Created \(preciseDate, style: .relative) ago")
            } else {
                Text("Created")
            }

        AttributionRow(
            leadingIcon: Image(systemName: "calendar"),
            trailingIcon: nil,
            mainText: dateText,
            caption: captionText
        )
    }

    @ViewBuilder
    private var uploadedDateLine: some View {
        let uploadDate = mediaFile.uploadDate

        AttributionRow(
            leadingIcon: Image(systemName: "arrow.up"),
            trailingIcon: nil,
            mainText: Text(uploadDate, style: .date),
            caption: Text("Uploaded \(uploadDate, style: .relative) ago")
        )
    }
}

private struct SourceLine: View {
    let isFileCreatedByUploader: Bool
    let sourceTextRaw: String?
    let sourceWikidataID: String?


    private static let knownHosts = [
        "flickr.com", "geograph.org.uk", "geo.hlipp.de", "geo-en.hlipp.de",
    ]

    private var knownHosts: [String] {
        // TODO: check against previously detected urls (faster and can be used for hostname display better)
        // needs some form of caching, either in the attributed string where urls are already extracted or
        // via DataDetection import and cached.
        guard let sourceTextRaw else { return [] }
        return Self.knownHosts.filter { host in
            sourceTextRaw.contains(host)
        }

    }

    private var sourceText: Text {
        if isFileCreatedByUploader {
            // TODO: distinguish between self-photographed and own
            Text("Own")
        } else if let sourceTextRaw {
            // TODO: normalize display of known hosts (flickr etc.)
            Text(AttributedStringCache.shared[sourceTextRaw] ?? "")
        } else {
            Text("Unknown")
        }
    }

    var body: some View {
        // TODO: handle long texts (eg. Bundesarchiv) with "show more" ?

        AttributionRow(
            leadingIcon: Image(systemName: "document"),
            trailingIcon: nil,
            mainText: sourceText,
            caption: Text("Source")
        )

    }
}


private struct UploaderLineLabel: View {
    let username: String

    var body: some View {

        HStack {
            Image(.customPersonBadgeArrowUp)
                .padding()
                .background(.ultraThinMaterial, in: .circle)


            VStack(alignment: .leading) {
                Text(username)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                Text("Uploader")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
        }

    }
}

private struct AuthorLineLabel: View {
    let url: URL?
    let name: String?
    var isFileCreatedByUploader: Bool

    var body: some View {
        let caption = isFileCreatedByUploader ? Text("Author and uploader") : Text("Author")

        AttributionRow(
            leadingIcon: Image(systemName: "person"),
            trailingIcon: Image(systemName: "info.circle"),
            mainText: Text(name ?? "Unknown"),
            caption: caption
        )
    }
}


struct AttributionRow<Icon: View>: View {
    let leadingIcon: Icon
    let trailingIcon: Image?
    let mainText: Text
    let caption: Text?

    var body: some View {
        HStack {

            leadingIcon
                .padding()
                .background(.ultraThinMaterial, in: .circle)

            VStack(alignment: .leading) {
                mainText
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fontWeight(.semibold)

                if let caption {
                    caption
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .allowsTightening(true)
                }
            }

            Spacer(minLength: 0)

            if let trailingIcon {
                trailingIcon
            }
        }
    }
}


#Preview(traits: .previewEnvironment) {
    VStack {
        AttributionDetailView(mediaFile: .makeRandomUploaded(id: "1", .squareImage))
            .padding()
    }
}
