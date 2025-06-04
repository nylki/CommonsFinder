//
//  WikidataClaim.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 26.10.24.
//

import Alamofire
import CommonsAPI
import CoreLocation
import Foundation

extension WikidataClaim: @retroactive Identifiable {
    public var id: String {
        if let mainItem {
            "\(mainProp.rawValue)=\(mainItem.id)"
        } else {
            mainProp.rawValue
        }
    }
}
