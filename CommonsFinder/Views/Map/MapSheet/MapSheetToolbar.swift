//
//  MapSheetToolbar.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 24.11.25.
//

import SwiftUI

struct MapSheetToolbar: ToolbarContent {
    let model: SelectedMapItemModel
    let onClose: () -> Void

    var title: LocalizedStringResource {
        lazy var formatter = MeasurementFormatter()

        if model is MediaInClusterModel {
            return "Images in area"
        } else if model is CategoriesInClusterModel {
            return "Locations in area"
        } else if let model = model as? MediaAroundLocationModel {
            let formattedRadius = formatter.string(from: .init(value: model.radius, unit: UnitLength.meters))
            return "Images (\(formattedRadius) radius)"
        } else if let model = model as? CategoriesAroundLocationModel {
            let formattedRadius = formatter.string(from: .init(value: model.radius, unit: UnitLength.meters))
            return "Locations (\(formattedRadius) radius)"
        } else {
            return ""
        }
    }

    var imageName: String {
        if model is ClusterRepresentation {
            "button.angledbottom.horizontal.left"
        } else if model is CircleRepresentation {
            "mappin.and.ellipse"
        } else {
            "mappin.and.ellipse"
        }
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if let model = (model as? MapItemWithSubItems), model.maxCount > 1 {
                CounterView(current: (model.focusedIdx ?? 0) + 1, max: model.maxCount)
            } else if #available(iOS 26.0, *) {
                
            } else {
                Color.clear.frame(width: 70)
            }
        }


        ToolbarItem(placement: .title) {
            HStack(spacing: 5) {
                Image(systemName: imageName)
                VStack(alignment: .leading) {
                    Text(title)
                        .bold()
                    // TODO: use wikidata item with area
                    Text(model.humanReadableLocation ?? "             ")
                        .lineLimit(1)
                        .font(.caption)
                }
                Spacer(minLength: 0)
            }
            .allowsTightening(true)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button("Close", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
        }
    }
}
