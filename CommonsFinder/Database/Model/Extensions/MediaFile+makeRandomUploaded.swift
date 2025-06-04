//
//  TestImageType.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 01.05.25.
//

import CommonsAPI
import Foundation
import UniformTypeIdentifiers

extension MediaFile {
    static func makeRandomUploaded(id: MediaFile.ID, _ imageType: TestImageType) -> MediaFile {
        let date: Date = Date(timeIntervalSince1970: .random(in: 1..<1_576_800_000))
        return MediaFile.init(
            id: id + String(Int64.random(in: 0..<Int64.max)),
            name: id,
            url: imageType.url,
            descriptionURL: imageType.url,
            thumbURL: imageType.url,
            width: 2000 * (imageType.aspect ?? 1),
            height: 2000 / (imageType.aspect ?? 1),
            uploadDate: date,
            caption: [.init("Lorem Ipsum Dolor Sitit in New York City, 1842", languageCode: "en"), .init("German localized paragraph: \(Lorem.paragraph)", languageCode: "de")],
            fullDescription: [
                .init(
                    "Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr.\n Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua.",
                    languageCode: "en")
            ],
            rawAttribution: "Some Obscure Archive / Archive Item Numer X.1234.5678 / Some Name / CC-BY 3.0",
            categories: ["Lorem Category", "Long name Category xyz Wiki Commons", "Short tags", "Short", "Location", "Something Else", "Random Things doing things in some city"],
            statements: [.depicts(.earth), .depicts(.universe), .copyrightStatus(.copyrightedDedicatedToThePublicDomainByCopyrightHolder), .license(.CC_BY_SA_2_5)],
            //            license: .draftSelectable.randomElement()!,
            mimeType: UTType(filenameExtension: imageType.rawValue.fileExtension())?.preferredMIMEType,
            username: "Testuser",
            fetchDate: .now
        )
    }
}

enum TestImageType: String {
    case verticalImage = "https://upload.wikimedia.org/wikipedia/commons/4/41/Vertical_panorama_-_Prescott_%2821174589204%29.jpg"
    case horizontalImage = "https://upload.wikimedia.org/wikipedia/commons/9/97/Banner_wikigap2023_1.jpg"
    case squareImage = "https://upload.wikimedia.org/wikipedia/commons/d/d1/CommonsAppTest_3.jpg"

    var url: URL { URL(string: rawValue)! }
}

extension TestImageType {
    var aspect: Double? {
        switch self {
        case .verticalImage:
            0.2
        case .horizontalImage:
            // panorama
            32 / 9
        case .squareImage:
            1
        }
    }
}
