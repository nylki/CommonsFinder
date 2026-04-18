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
                .overlay {
                    let stops: [Gradient.Stop] =
                        switch colorScheme {
                        case .light:
                            [
                                .init(color: .accent.opacity(0.2), location: 0),
                                .init(color: .accent.opacity(0.25), location: 0.2),
                                .init(color: .accent.opacity(0.5), location: 0.35),
                                .init(color: .accent.opacity(1), location: 0.5),
                                .init(color: .accent.opacity(1), location: 1),
                            ]
                        case .dark:
                            [
                                .init(color: .accent.opacity(0.15), location: 0),
                                .init(color: .accent.opacity(0.15), location: 0.2),
                                .init(color: .accent.opacity(0.2), location: 0.35),
                                .init(color: .accent.opacity(0.4), location: 0.5),
                                .init(color: .accent.opacity(1), location: 1),
                            ]
                        @unknown default:
                            fatalError()
                        }

                    ContainerRelativeShape()
                        .stroke(LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom), lineWidth: 3)
                }
                .background(colorScheme == .light ? .white : .black)
                .compositingGroup()
                .drawingGroup()
        }
    }


    @ViewBuilder
    private var fallbackBackground: some View {
        switch colorScheme {
        case .light:
            LinearGradient(
                stops: [
                    .init(color: .accent.opacity(0.01), location: 0),
                    .init(color: .accent.opacity(0.05), location: 0.2),
                    .init(color: .accent.opacity(0.3), location: 0.45),
                    .init(color: .accent.opacity(0.85), location: 0.85),
                    .init(color: .accent.opacity(1), location: 1),
                ], startPoint: .top, endPoint: .bottom)


        case .dark:
            LinearGradient(
                stops: [
                    .init(color: .accent.opacity(0.1), location: 0),
                    .init(color: .accent.opacity(0.15), location: 0.45),
                    .init(color: .accent.opacity(0.4), location: 0.75),
                    .init(color: .accent.opacity(1), location: 1),
                ], startPoint: .top, endPoint: .bottom)

        @unknown default:
            fatalError()
        }
    }
}

#Preview {
    VStack {
        CategoryTeaserBackground(category: .earth)
        CategoryTeaserBackground(category: .earthNoImage).frame(height: 70)
        CategoryTeaserBackground(category: .earthNoImage)
    }
    .padding()
    .containerShape(.rect(cornerRadius: 32))

}
