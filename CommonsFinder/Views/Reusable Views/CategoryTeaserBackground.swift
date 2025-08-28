//
//  CategoryTeaserBackground.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 29.11.25.
//

import NukeUI
import SwiftUI

struct CategoryTeaserBackground: View {
    let category: Category

    var body: some View {
        Color(.emptyWikiItemBackground)
            .overlay {
                if let imageRequest = category.thumbnailImage {
                    LazyImage(request: imageRequest, transaction: .init(animation: .linear)) { imageState in
                        if let image = imageState.image {
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .scaledToFill()
                        } else {
                            Color.clear
                        }
                    }
                } else {
                    ProceduralBackground(categoryName: category.commonsCategory ?? category.wikidataId ?? "")
                        .blur(radius: 5)
                        .clipped()
                }
            }
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .init(white: 0, opacity: 0), location: 0),
                        .init(color: .init(white: 0, opacity: 0.1), location: 0.35),
                        .init(color: .init(white: 0, opacity: 0.2), location: 0.5),
                        .init(color: .init(white: 0, opacity: 0.8), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
            }
    }
}
