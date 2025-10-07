//
//  FallbackButtonRole.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 07.10.25.
//

import SwiftUI

extension ButtonRole {
    static var fallbackClose: Self {
        if #available(iOS 26.0, *) {
            ButtonRole.close
        } else {
            ButtonRole.cancel
        }
    }

    static var fallbackConfirm: Self? {
        if #available(iOS 26.0, *) {
            ButtonRole.confirm
        } else {
            nil
        }
    }
}
