//
//  UploadProgressDelegate.swift
//  CommonsAPI
//
//  Created by Tom Brewe on 12.12.25.
//

import Foundation

internal final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
    typealias ProgressHandler = @Sendable (Progress) -> Void
    let progressHandler: ProgressHandler
    
    init(progressHandler: @escaping ProgressHandler) {
        self.progressHandler = progressHandler
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = Progress(totalUnitCount: totalBytesExpectedToSend)
        progress.completedUnitCount = totalBytesSent
        progressHandler(progress)
    }
}
