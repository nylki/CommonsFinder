//
//  ClusterAnnotation.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.03.25.
//

import MapKit
import SwiftUI

struct ClusterAnnotation: View {
    let mediaCount: Int
    let wikiItemCount: Int
    let isSelected: Bool
    let onTap: () -> Void

    @Namespace private var namespace
    @State private var isInteracting = false

    private func numberText(count: Int) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let thousand = Double(count) / 1000

        switch count {
        case 0..<1000:
            return formatter.string(from: .init(value: count))
        case 1000..<10000:
            formatter.maximumFractionDigits = 1
            let formatted = formatter.string(from: .init(value: thousand)) ?? "\(count)"
            return "\(formatted)K"
        default:
            formatter.maximumFractionDigits = 0
            let formatted = formatter.string(from: .init(value: thousand)) ?? "\(count)"
            return "\(formatted)K"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            if wikiItemCount != 0 {
                Text(numberText(count: wikiItemCount) ?? "\(wikiItemCount)")
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.purple.opacity(0.2))
            }

            if wikiItemCount != 0, mediaCount != 0 {
                Divider()
            }

            if mediaCount != 0 {
                Text(numberText(count: mediaCount) ?? "\(mediaCount)")
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.yellow.opacity(0.2))
            }
        }
        .font(.caption.bold())
        .background(.cardBackground)
        .clipShape(.capsule)
        .overlay {
            Capsule().stroke(.background, lineWidth: isSelected ? 3 : 2)
        }
        .compositingGroup()
        .shadow(color: Color.primary.opacity(0.4), radius: 2)
        .onTapGesture(perform: onTap)
        .animation(.default, value: isInteracting)
        .animation(.default, value: isSelected)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview(traits: .previewEnvironment) {
    Map {
        Annotation("", coordinate: .init(latitude: 50, longitude: 2)) {
            ClusterAnnotation(mediaCount: 5, wikiItemCount: 1, isSelected: false, onTap: {})
        }

        Annotation("", coordinate: .init(latitude: 50.01, longitude: 2.01)) {
            ClusterAnnotation(mediaCount: 999, wikiItemCount: 10, isSelected: true, onTap: {})
        }

        Annotation("", coordinate: .init(latitude: 50.015, longitude: 2.012)) {
            ClusterAnnotation(mediaCount: 0, wikiItemCount: 10, isSelected: true, onTap: {})
        }

        Annotation("", coordinate: .init(latitude: 49.995, longitude: 2.005)) {
            ClusterAnnotation(mediaCount: 1, wikiItemCount: 10000, isSelected: false, onTap: {})
        }

        Annotation("", coordinate: .init(latitude: 50.005, longitude: 1.999)) {
            ClusterAnnotation(mediaCount: 3111, wikiItemCount: 0, isSelected: false, onTap: {})
        }

        Annotation("", coordinate: .init(latitude: 50.02, longitude: 2.02)) {
            ClusterAnnotation(mediaCount: 124567, wikiItemCount: 5, isSelected: false, onTap: {})
        }
    }


}
