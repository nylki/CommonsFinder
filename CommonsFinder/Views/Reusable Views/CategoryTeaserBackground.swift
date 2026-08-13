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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
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
            .overlay {
                if category.thumbnailImage != nil {
                    LinearGradient(
                        stops: [
                            .init(color: .init(white: 0, opacity: 0), location: 0),
                            .init(color: .init(white: 0, opacity: 0.1), location: 0.35),
                            .init(color: .init(white: 0, opacity: 0.2), location: 0.5),
                            .init(color: .init(white: 0, opacity: 0.8), location: 1),
                        ], startPoint: .top, endPoint: .bottom)
                }
            }
            .clipShape(.containerRelative)
        } else {
            fallbackBackground
                .overlay(alignment: .topTrailing) {
                    categoryIcon
                }
        }
    }


    @ViewBuilder
    private var categoryIcon: some View {
        iconForCategory(category)
            .font(.system(size: 63))
            .foregroundStyle(.accent.opacity(0.2))
            .padding([.trailing, .top], 20)
    }


    private func iconForCategory(_ category: Category) -> Image {
        // TODO: pick a fitting icon depending on wikidata info
        // or category name (eg. category.commonsCategory?.localizedStandardContains("streets in")
        return Image(systemName: "tag")
    }

    @ViewBuilder
    private var fallbackBackground: some View {
        switch colorScheme {
        case .light:
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.929, green: 0.949, blue: 0.937), location: 0),
                    .init(color: Color(red: 0.886, green: 0.922, blue: 0.898), location: 0.45),
                    .init(color: Color(red: 0.726, green: 0.827, blue: 0.773), location: 1),
                ], startPoint: .top, endPoint: .bottom
            )
        case .dark:
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.118, green: 0.231, blue: 0.180), location: 0),
                    .init(color: Color(red: 0.106, green: 0.200, blue: 0.165), location: 0.45),
                    .init(color: Color(red: 0.078, green: 0.140, blue: 0.110), location: 1),
                ], startPoint: .top, endPoint: .bottom
            )
        @unknown default:
            fatalError()
        }
    }
}

#Preview {
    VStack {
        CategoryTeaserBackground(category: .earth)
            .clipShape(.rect(cornerRadius: 32))
        CategoryTeaserBackground(category: .earthNoImage)
            .clipShape(.rect(cornerRadius: 32))
    }
    .padding()


}
