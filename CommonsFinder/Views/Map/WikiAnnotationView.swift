//
//  WikiAnnotationView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 25.10.25.
//

import CommonsAPI
import MapKit
import NukeUI
import SwiftUI
import os.log

struct WikiAnnotationView: View {
    let item: Category
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isVisible = false

    var body: some View {
        let shape = Circle()
        let diameter: Double = isSelected ? 45 : 35
        ZStack {

            if let imageRequest = item.thumbnailImage {
                LazyImage(request: imageRequest) { imageLoadingState in
                    if isVisible, let image = imageLoadingState.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: diameter, height: diameter)
                            .clipShape(shape)
                            .transition(.opacity)
                    } else if imageLoadingState.isLoading {
                        shape
                            .fill(.clear)
                            .frame(width: diameter, height: diameter)
                    } else {
                        shape
                            .fill(.accent)
                            .opacity(isVisible ? 1 : 0)
                            .frame(width: diameter, height: diameter)
                    }
                }
            } else {
                Color.accent.opacity(isVisible ? 1 : 0)
                    .frame(width: diameter, height: diameter)
                    .clipShape(shape)
            }
        }
        .overlay {
            shape
                .stroke(.background, lineWidth: 2)
                .opacity(isVisible ? 1 : 0)
        }
        .scaleEffect(isVisible ? 1 : 0.3, anchor: .center)
        .geometryGroup()
        .compositingGroup()
        //        .modifier(CategoryContextMenu(item: .init(item)))
        .shadow(color: Color.primary.opacity(0.4), radius: 5)
        .animation(.bouncy, value: isVisible)
        .animation(.bouncy, value: isSelected)
        .onTapGesture(perform: onTap)
        .task {
            do {
                try await Task.sleep(for: .milliseconds(25))
                isVisible = true
            } catch {}
        }

    }
}


#Preview(traits: .previewEnvironment) {
    @Previewable @Namespace var namespace
    @Previewable @Environment(Navigation.self) var navigation
    let onTap = {
        print("tap")
    }
    Map {
        Annotation("", coordinate: .init(latitude: 50, longitude: 2)) {
            WikiAnnotationView(item: .earth, isSelected: true) {}
                .environment(navigation)
        }

        Annotation("", coordinate: .init(latitude: 50.01, longitude: 2.01)) {
            WikiAnnotationView(item: .earth, isSelected: false) {}
                .environment(navigation)
        }

        Annotation("", coordinate: .init(latitude: 50.015, longitude: 2.012)) {
            WikiAnnotationView(item: .earth, isSelected: false) {}
                .environment(navigation)
        }

        Annotation("", coordinate: .init(latitude: 49.995, longitude: 2.005)) {
            WikiAnnotationView(item: .earth, isSelected: false) {}
                .environment(navigation)
        }

        Annotation("", coordinate: .init(latitude: 50.005, longitude: 1.999)) {
            WikiAnnotationView(item: .earth, isSelected: false) {}
                .environment(navigation)
        }

        Annotation("", coordinate: .init(latitude: 50.02, longitude: 2.02)) {
            WikiAnnotationView(item: .earth, isSelected: false) {}
                .environment(navigation)
        }
    }
}
