//
//  HomeView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 24.09.24.
//

import GRDBQuery
import Nuke
import SwiftUI
import TipKit

struct HomeView: View {
    @Environment(Navigation.self) private var navigation
    @Environment(AccountModel.self) private var account

    @Query(AllDraftsRequest()) private var drafts
    @Query(AllRecentlyViewedMediaFileRequest()) private var recentlyViewedFiles

    var body: some View {

        ScrollView(.vertical) {
            VStack {
                TipView(HomeTip())
                    .padding()

                if !drafts.isEmpty {
                    DraftsSection(drafts: drafts)
                        .transition(.blurReplace)
                }


                VStack(spacing: 25) {
                    if let activerUser = account.activeUser {
                        HorizontalUploadsSection(username: activerUser.username)
                    }

                    if !recentlyViewedFiles.isEmpty {
                        HorizontalFileListSection(
                            label: "Recently Viewed",
                            destination: .recentlyViewed,
                            mediaFileInfos: recentlyViewedFiles
                        )
                    }
                }

                // This space-filling clear rect avoids unwanted scale-up
                // animations when the first ScrollView content appears (eg. the Tip)
                Color.clear.scaledToFill()
            }
            .padding(.top)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .shadow(color: .black.opacity(0.125), radius: 10, y: 7)
        .shadow(color: .black.opacity(0.075), radius: 100, y: 7)
        .animation(.default, value: drafts)
        .animation(.default, value: recentlyViewedFiles)
        .animation(.default, value: account.activeUser)
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: NavigationStackItem.settings) {
                    Label("Settings", systemImage: "person.crop.circle.fill")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Image", systemImage: "plus", action: navigation.openNewDraft)
            }
        }
    }
}


#Preview(traits: .previewEnvironment) {
    HomeView()
}
