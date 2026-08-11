//
//  File.swift
//  CommonsFinder
//
//  Created by Tom on 29.07.26.
//


extension MediaFileDraft.PublishingState? {
    var isEditingPossible: Bool {
        switch self {
        case .uploading(_):
            true
        case .uploaded(_):
            true
        case .unstashingFile(_):
            true
        case .creatingWikidataClaims:
            false
        case .published:
            false
        case nil:
            true
        }
    }
}
