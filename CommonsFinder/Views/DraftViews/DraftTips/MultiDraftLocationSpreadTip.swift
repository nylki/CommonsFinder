//
//  MultiDraftLocationSpreadTip.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 14.07.26.
//

import TipKit

struct MultiDraftLocationSpreadTip: Tip {
    let id: String

    init(multiDraftID: MultiDraft.MultiDraftID?) {
        if let multiDraftID {
            id = "MultiDraftLocationSpreadTip-\(multiDraftID)"
        } else {
            // for nil-ids (which are drafts not yet persisted in DB) it's ok to just use a UUID here.
            id = UUID().uuidString
        }
    }

    var options: [any TipOption] {
        IgnoresDisplayFrequency(true)
    }

    var title: Text {
        Text("Check file locations")
    }

    var message: Text? {
        let measurementFormatter = MeasurementFormatter()
        let dist = Measurement(value: ViewConstants.multiDraftMaxFileDistanceWarningThreshold, unit: UnitLength.meters)
        let formattedDist = measurementFormatter.string(from: dist)
        return Text("Some of the files were created more than \(formattedDist) apart from each other. Consider double-checking them and be mindful when adding captions and categories.")
    }

    var image: Image? {
        Image(systemName: "mappin.and.ellipse")
    }
}
