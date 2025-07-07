//
//  CategoryListItem.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 07.07.25.
//

import NukeUI
import SwiftUI

struct CategoryListItem: View {
    let categoryInfo: CategoryInfo
    let namespace: Namespace.ID

    var body: some View {
        let backgroundImage = categoryInfo.base.thumbnailImage
        let hasBackgroundImage = backgroundImage != nil
        let label = categoryInfo.base.label ?? categoryInfo.base.commonsCategory

        NavigationLink(value: NavigationStackItem.wikidataItem(categoryInfo)) {
            HStack {
                VStack {
                    Spacer()

                    VStack(alignment: .leading) {
                        if let label {
                            Text(label)
                        }
                        if let description = categoryInfo.base.description {
                            Text(description)
                                .font(.caption)
                                .allowsTightening(true)
                        }
                    }
                    .shadow(color: hasBackgroundImage ? .black : .clear, radius: 2)
                    .shadow(color: .black.opacity(0.7), radius: 7)

                }
                .multilineTextAlignment(.leading)
                .foregroundStyle(Color.white)

                Spacer(minLength: 0)
            }
            .frame(height: 170)
            .padding()
            .background {
                Color(.emptyWikiItemBackground)
                    .overlay {
                        if let imageRequest = categoryInfo.base.thumbnailImage {
                            LazyImage(request: imageRequest, transaction: .init(animation: .linear)) { imageState in
                                if let image = imageState.image {
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .scaledToFill()
                                } else {
                                    Color.clear
                                }
                            }
                        }
                    }
                    .overlay {
                        if categoryInfo.base.thumbnailImage != nil {
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
            .clipShape(.rect(cornerRadius: 25))

        }
        .modifier(CategoryContextMenu(item: categoryInfo))
    }
}

#Preview {
    @Previewable @Namespace var namespace
    ScrollView(.vertical) {
        LazyVStack {
            CategoryListItem(categoryInfo: .init(.earth), namespace: namespace)
            CategoryListItem(categoryInfo: .init(.earthNoImage), namespace: namespace)
            CategoryListItem(categoryInfo: .init(.earthExtraLongLabel), namespace: namespace)
            CategoryListItem(categoryInfo: .init(.testItemNoDesc), namespace: namespace)
            CategoryListItem(categoryInfo: .init(.testItemNoLabel), namespace: namespace)
            CategoryListItem(categoryInfo: .init(.randomItem(id: "random")), namespace: namespace)
        }
    }
    .scenePadding()
}
