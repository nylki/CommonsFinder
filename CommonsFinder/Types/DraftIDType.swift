//
//  DraftIDType.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.04.26.
//

import Foundation

enum DraftIDType: Hashable, Identifiable, Equatable, CustomStringConvertible {
    case singleDraft(MediaFileDraft.ID)
    case multiDraft(MultiDraft.MultiDraftID)

    var id: String {
        switch self {
        case .singleDraft(let id): id
        case .multiDraft(let id): String(id)
        }
    }

    var multiDraftID: Int64? {
        switch self {
        case .singleDraft(_): nil
        case .multiDraft(let id): id
        }
    }

    var isMultiDraft: Bool {
        switch self {
        case .singleDraft(_): false
        case .multiDraft(_): true
        }
    }

    var description: String {
        switch self {
        case .singleDraft(let id):
            id
        case .multiDraft(let multiDraftID):
            String(multiDraftID)
        }
    }
}
