//
//  String+FileExtension.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 08.11.24.
//

import Foundation

extension String {
    func fileName() -> String {
        return URL(fileURLWithPath: self).deletingPathExtension().lastPathComponent
    }
    
    func fileExtension() -> String {
        return URL(fileURLWithPath: self).pathExtension
    }
}
