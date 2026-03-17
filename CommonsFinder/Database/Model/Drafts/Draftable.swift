//
//  Draftable.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 13.03.26.
//

import Foundation

nonisolated protocol Draftable {
    var addedDate: Date { get }
    var captionWithDesc: [CaptionWithDescription] { get }
    var tags: [TagItem]  { get }
    var license: DraftMediaLicense?  { get }
    var author: DraftAuthor? { get }
    var source: DraftSource? { get }
}
