//
//  HorizontalUploadsSection.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 09.01.25.
//


import GRDBQuery
import SwiftUI

/// Displays uploads of a given username in a horizontal list with a NavigationLink-header
/// too see the full list in a separate navigation destination.
struct HorizontalUploadsSection: View {
    let username: String

    @State private var request: AllUploadsRequest?

    var body: some View {
        ZStack {
            if let request {
                WrappedUploadsSection(request)
                    .id(username)
            } else {
                EmptyView()
            }
        }
        .onChange(of: username, initial: true) {
            request = AllUploadsRequest(username: username)
        }
    }
}

private struct WrappedUploadsSection: View {
    @Query<AllUploadsRequest> private var mediaFileInfos: [MediaFileInfo]
    let destination: NavigationStackItem

    init(_ request: AllUploadsRequest) {
        _mediaFileInfos = Query(request)
        destination = .userUploads(username: request.username)
    }

    var body: some View {
        if mediaFileInfos.isEmpty {
            EmptyView()
        } else {
            HorizontalFileListSection(
                label: "Uploads",
                destination: destination,
                mediaFileInfos: mediaFileInfos
            )
        }


    }
}

#Preview(traits: .previewEnvironment) {
    HorizontalUploadsSection(username: "")
}
