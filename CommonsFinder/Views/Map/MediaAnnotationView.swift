//
//  MediaAnnotationView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 25.10.25.
//

import CommonsAPI
import MapKit
import NukeUI
import SwiftUI
import os.log

struct MediaAnnotationView: View {
    let item: MediaFileInfo?
    let namespace: Namespace.ID
    let isSelected: Bool

    let onTap: () -> Void

    @State private var isVisible = false

    var body: some View {
        let diameter: Double = isSelected ? 45 : 35
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        ZStack {
            if let item, isVisible {
                MediaFileThumbImage(mediaFileImage: item)
                    .frame(width: diameter, height: diameter)
                    .clipShape(shape)
                    .matchedTransitionSource(id: item.id, in: namespace)
            } else {
                shape.fill(.clear).frame(width: diameter, height: diameter)
            }
        }
        .overlay {
            shape
                .stroke(.background, lineWidth: 2)
                .opacity(isVisible ? 1 : 0)
        }

        .compositingGroup()
        .geometryGroup()
        .clipShape(shape)
        .scaleEffect(isVisible ? 1 : 0.3, anchor: .center)
        .contentShape(shape)
        .contentShape([.interaction, .contextMenuPreview], shape)
        //        .modifier(MediaFileContextMenu(mediaFileInfo: item, namespace: namespace))
        .shadow(color: Color.primary.opacity(isSelected ? 0.8 : 0.4), radius: isSelected ? 2 : 1)
        .animation(.bouncy, value: isVisible)
        .onTapGesture(perform: onTap)
        .task {
            try? await Task.sleep(for: .milliseconds(25))
            isVisible = true
        }

    }

}

#Preview(traits: .previewEnvironment) {
    @Previewable @Namespace var namespace
    @Previewable @Environment(Navigation.self) var navigation
    let onTap = { print("tap") }
    Map {
        Annotation("", coordinate: .init(latitude: 50, longitude: 2)) {
            MediaAnnotationView(item: .makeRandomUploaded(id: "1", .horizontalImage), namespace: namespace, isSelected: true) {}
                .environment(navigation)
        }

        Annotation("", coordinate: .init(latitude: 50.01, longitude: 2.01)) {
            MediaAnnotationView(item: .makeRandomUploaded(id: "1", .horizontalImage), namespace: namespace, isSelected: false) {}
                .environment(navigation)
        }

        Annotation("", coordinate: .init(latitude: 50.015, longitude: 2.012)) {
            MediaAnnotationView(item: .makeRandomUploaded(id: "1", .horizontalImage), namespace: namespace, isSelected: false) {}
                .environment(navigation)
        }

        Annotation("", coordinate: .init(latitude: 49.995, longitude: 2.005)) {
            MediaAnnotationView(item: .makeRandomUploaded(id: "1", .horizontalImage), namespace: namespace, isSelected: false) {}
                .environment(navigation)
        }

        Annotation("", coordinate: .init(latitude: 50.005, longitude: 1.999)) {
            MediaAnnotationView(item: .makeRandomUploaded(id: "1", .horizontalImage), namespace: namespace, isSelected: false) {}
                .environment(navigation)
        }

        Annotation("", coordinate: .init(latitude: 50.02, longitude: 2.02)) {
            MediaAnnotationView(item: .makeRandomUploaded(id: "1", .horizontalImage), namespace: namespace, isSelected: false) {}
                .environment(navigation)
        }
    }
}
