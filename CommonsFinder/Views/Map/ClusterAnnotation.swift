//
//  ClusterAnnotation.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.03.25.
//

import MapKit
import SwiftUI

struct ClusterAnnotation: View {
    let pickedItemType: MapItemType
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

    var shape: AnyShape {
        pickedItemType == .mediaItem ? AnyShape(RoundedRectangle(cornerRadius: 4, style: .continuous)) : AnyShape(.circle)
    }

    var body: some View {

        HStack(spacing: 0) {
            switch pickedItemType {
            case .mediaItem:
                Text(numberText(count: mediaCount) ?? "\(mediaCount)")
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.yellow.opacity(0.2))
            case .wikiItem:
                Text(numberText(count: wikiItemCount) ?? "\(wikiItemCount)")
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.purple.opacity(0.2))
            }
        }
        .font(.system(size: 12).bold())
        .tint(.primary)
        .background(.cardBackground)
        .clipShape(shape)
        .overlay {
            shape.stroke(.background, lineWidth: isSelected ? 3 : 2)
        }
        .compositingGroup()
        .shadow(color: Color.primary.opacity(0.4), radius: 2)
        .padding()
        //            .background(Color.red)
        .clipShape(shape)
        .onTapGesture(perform: onTap)
        .animation(.default, value: isInteracting)
        .animation(.default, value: isSelected)
        .animation(.default, value: pickedItemType)


    }
}

#Preview(traits: .previewEnvironment) {
    @Previewable @State var pickedItemType = MapItemType.mediaItem
    let onTap = {
        print("tap")
    }
    Map {
        Annotation("", coordinate: .init(latitude: 50, longitude: 2)) {
            ClusterAnnotation(pickedItemType: pickedItemType, mediaCount: 5, wikiItemCount: 1, isSelected: false, onTap: onTap)
        }

        Annotation("", coordinate: .init(latitude: 50.01, longitude: 2.01)) {
            ClusterAnnotation(pickedItemType: pickedItemType, mediaCount: 999, wikiItemCount: 10, isSelected: true, onTap: onTap)
        }

        Annotation("", coordinate: .init(latitude: 50.015, longitude: 2.012)) {
            ClusterAnnotation(pickedItemType: pickedItemType, mediaCount: 0, wikiItemCount: 10, isSelected: true, onTap: onTap)
        }

        Annotation("", coordinate: .init(latitude: 49.995, longitude: 2.005)) {
            ClusterAnnotation(pickedItemType: pickedItemType, mediaCount: 1, wikiItemCount: 10000, isSelected: false, onTap: onTap)
        }

        Annotation("", coordinate: .init(latitude: 50.005, longitude: 1.999)) {
            ClusterAnnotation(pickedItemType: pickedItemType, mediaCount: 3111, wikiItemCount: 0, isSelected: false, onTap: onTap)
        }

        Annotation("", coordinate: .init(latitude: 50.02, longitude: 2.02)) {
            ClusterAnnotation(pickedItemType: pickedItemType, mediaCount: 124567, wikiItemCount: 5, isSelected: false, onTap: onTap)
        }
    }
    .overlay(alignment: .top) {
        Picker("", selection: $pickedItemType) {

            Text("Locations")
                .tag(MapItemType.wikiItem)

            Text("Images")
                .tag(MapItemType.mediaItem)
        }
        .pickerStyle(.segmented)
        .frame(minWidth: 0, maxWidth: .infinity)
        .padding(.horizontal)
    }


}
