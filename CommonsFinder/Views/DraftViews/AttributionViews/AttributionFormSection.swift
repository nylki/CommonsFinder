//
//  AttributionFormSection.swift
//  CommonsFinder
//
//  Created by Tom on 10.11.26.
//

import SwiftUI

struct AttributionFormSection: View {
    let draft: Draftable
    @Environment(AccountModel.self) private var account
    @Binding var isAttributionSheetShowing: Bool

    var body: some View {
        Section("Attribution & License") {
            authorRow
            sourceRow
            licenseRow
            editButton
        }
    }

    @ViewBuilder private var licenseRow: some View {
        if let license = draft.license {
            HStack {
                Text("License")
                Spacer(minLength: 0)
                Text(license.abbreviation)
            }
        }
    }

    @ViewBuilder private var editButton: some View {
        Button {
            isAttributionSheetShowing = true
        } label: {
            Label("Edit", systemImage: "pencil")
        }
    }

    @ViewBuilder
    private var authorRow: some View {
        if draft.author != .unknown,
            draft.author != nil
        {
            HStack {
                Text("Author")
                Spacer(minLength: 0)
                switch draft.author {
                case .appUser:
                    if let activeUsername = account.activeUser?.username {
                        Text(activeUsername)
                    } else {
                        VStack {
                            Text("You")
                            Text("not signed in")
                                .font(.caption)
                        }


                    }

                case .custom(let customAuthor):
                    if let url = customAuthor.url {
                        Link(destination: url) { baseCustomAuthorText }
                    } else {
                        baseCustomAuthorText
                    }

                case .wikidataId(let wikidataItem):
                    // not yet supported
                    EmptyView()
                case .unknown, .none:
                    Text("unknown author")
                }
            }
        }
    }

    @ViewBuilder
    private var sourceRow: some View {
        HStack {
            Text("Source")
            Spacer(minLength: 0)
            if draft.author == .appUser {
                Text("Own work")
            } else if case .otherSource(let string) = draft.source {
                Text("\(string)")
            }

        }

    }


    @ViewBuilder
    private var baseCustomAuthorText: some View {
        switch draft.author {
        case .custom(let customAuthor):
            if let wikimediaUsername = customAuthor.wikimediaUsername {
                Text(
                    "\(customAuthor.name) (\(wikimediaUsername))",
                    comment: "author name with wikimedia username in brackets"
                )
            } else {
                Text(customAuthor.name)
            }
        default: EmptyView()
        }
    }
}

#Preview {
    @Previewable @State var isSheetShowing = false
    @Previewable @State var draft: MediaFileDraft = .makeRandomEmptyDraft(id: "1")

    VStack {
        Form {
            AttributionFormSection(draft: draft, isAttributionSheetShowing: $isSheetShowing)
        }
    }
    .sheet(isPresented: $isSheetShowing) {
        AttributionDetailView(
            initialSource: draft.source,
            initialAuthor: draft.author,
            initialLicense: draft.license
        ) { source, author, license in
            draft.source = source
            draft.author = author
            draft.license = license
        }
    }
}
