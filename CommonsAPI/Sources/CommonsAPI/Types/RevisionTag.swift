//
//  File.swift
//  CommonsAPI
//
//  Created by Tom Brewe on 13.02.26.
//

import Foundation

// see: https://commons.wikimedia.org/wiki/Special:Tags
// NOTE: currently results in "badtags" error
public enum RevisionTag: String {
    case mobileEdit = "mobile edit"
    case iosAppEdit = "ios app edit"
    case mobileAppEdit = "mobile app edit"
    
    case appImageCaptionAdd = "app-image-caption-add"
    case appImageTagAdd = "app-image-tag-add"
    /// Edit made from article full source editor in the mobile apps
    case appFullSource = "app-full-source"
}
