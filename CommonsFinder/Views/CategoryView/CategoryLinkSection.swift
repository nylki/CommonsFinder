//
//  CategoryLinkSection.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.03.25.
//

import CommonsAPI
import SwiftUI

struct CategoryLinkSection: View {
    var item: CategoryInfo

    var body: some View {
        Section("Links") {
            if let wikidataID = item.base.wikidataId,
                let wikidataURL = item.base.wikidataURL
            {
                Menu("Wikidata") {
                    Text(wikidataID)

                    ControlGroup {
                        Button("Copy ID", systemImage: "document.on.document") {
                            UIPasteboard.general.string = wikidataID
                        }
                        ShareLink("Share", item: wikidataURL)
                        Link(destination: wikidataURL) {
                            Label("Open in Browser", systemImage: "globe")
                        }
                    }
                }
            }
            if let commonsCategory = item.base.commonsCategory,
                let url = item.base.commonsCategoryURL
            {
                Menu("Commons") {
                    Text(commonsCategory)
                    ControlGroup {
                        Button("Copy", systemImage: "document.on.document") {
                            UIPasteboard.general.string = commonsCategory
                        }
                        ShareLink("Share", item: url)
                        Link(destination: url) {
                            Label("Open in Browser", systemImage: "globe")
                        }
                    }

                }
            }
        }
    }
}

#Preview {
    CategoryLinkSection(item: .init(.earth))
    CategoryLinkSection(item: .randomItem(id: "2"))
    CategoryLinkSection(item: .init(.init(commonsCategory: "Category in Categories")))
}
