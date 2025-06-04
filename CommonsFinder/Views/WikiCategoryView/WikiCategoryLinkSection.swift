//
//  WikiCategoryLinkSection.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.03.25.
//

import CommonsAPI
import SwiftUI

struct WikiCategoryLinkSection: View {
    var wikidataItem: WikidataItem?
    var categoryName: String?

    var body: some View {
        Section("Links") {
            if let wikidataItem {
                Menu("Wikidata") {
                    Text(wikidataItem.id)
                    ShareLink("Share", item: wikidataItem.url)
                    Link(destination: wikidataItem.url) {
                        Label("Open in Browser", systemImage: "globe")
                    }
                    Button("Copy ID", systemImage: "document.on.document") {
                        UIPasteboard.general.string = wikidataItem.id
                    }
                }

            }
            if let categoryName,
                let url = URL(string: "https://commons.wikimedia.org/wiki/Category:\(categoryName)")
            {
                Menu("Commons") {
                    Text("Category: \(categoryName)")
                    ShareLink("Share", item: url)
                    Link(destination: url) {
                        Label("Open in Browser", systemImage: "globe")
                    }
                }
            }
        }
    }
}

#Preview {
    WikiCategoryLinkSection(wikidataItem: .randomItem(id: "1"))
    WikiCategoryLinkSection(wikidataItem: .randomItem(id: "2"), categoryName: "Foo")
    WikiCategoryLinkSection(categoryName: "Foo")
}
