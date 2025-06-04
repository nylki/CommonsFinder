//
//  ShareView.swift
//  CommonsFinderShareExtension
//
//  Created by Tom Brewe on 03.02.25.
//

import SwiftUI
import os.log
import UIKit
import UniformTypeIdentifiers
import MobileCoreServices

enum ShareResultError: Error {
    case failedToGetAppGroup
    case URLInitError
}

struct ShareView: View {
    let items: [NSItemProvider]
    let onSuccess: () -> Void
    let onError: (Error) -> Void
    
    @State private var currentProgress = Progress()
    @State private var currentFileProgressIdx: Int = 0
    @Environment(\.openURL) private var openURL
    
    private let logger = Logger(subsystem: "ShareExtension", category: "ShareView")
    
    var body: some View {
        // Currently, this view does nothing but to be the place to execute the start the save task and to call openURL(), since now further UI after the shareSheet is being shown and we directy open the app to work on the drafts.
        // This SwiftUI setup is kept in place in-case for the time being, if at some point a more elaborate dialog should be shown.

        // Ideas/Options for additional dialog: file format chooser, save-to-commons-online-stash or save-to-draft without opening the app
        ProgressView()
            .task {
                await saveDraftsAndOpenApp()
            }
    }

    @discardableResult
    private func saveDrafts() async throws -> [URL] {
        // For now the list of share images/files is processed serially,
        // Maybe convert to TaskGroup for parallel loading. But can get tricky with concurrency
        // may need to extract some logic if we do that.
        logger.info("Saving drafts...")
        guard let shareExtensionContainerURL = URL.shareExtensionContainerURL else {
            throw ShareResultError.failedToGetAppGroup
        }

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: shareExtensionContainerURL, withIntermediateDirectories: true)
        
            var succesfulURLs: [URL] = []
            var fileURLs: [URL] = []
            
            for attachment in items {
                
                guard attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier as String) else {
                    continue
                }
                
                do {
                    let result = try await withCheckedThrowingContinuation { continuation in
                        let progress = attachment.loadFileRepresentation(for: .image, openInPlace: true) { url, inPlace, error in
                            if let url {
                                continuation.resume(returning: url)
                            } else if let error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(throwing: ShareError.failedToLoadFileRepresentation)
                            }
                        }
                        
                        currentProgress = progress
                    }
                    fileURLs.append(result)
                } catch {
                    logger.error("Failed to load a a file: \(error)")
                }
            }
            
            // Now that we have a list of file URLs, copy them to the AppGroup so they can be opened
            // from the App.

            for fileURL in fileURLs {
                do {
                    let newFileURL = shareExtensionContainerURL
                        .appending(component: UUID().uuidString)
                        .appendingPathExtension(fileURL.pathExtension)
                    
                    try fileManager.copyItem(at: fileURL, to: newFileURL)
                    succesfulURLs.append(newFileURL)
                } catch {
                    logger.error("Failed to copy file to app group. \(error)")
                }
            }
            
        return succesfulURLs
    }
    
    private func saveDraftsAndOpenApp() async {
        let draftURLs: [URL]
        do {
            draftURLs = try await saveDrafts()
        } catch {
            logger.error("failed to save drafts. \(error)")
            onError(error)
            return
        }
        
        guard let url = URL(string: "CommonsFinder://ShareExtension/openDrafts"),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            onError(ShareResultError.URLInitError)
            return
        }
        components.queryItems = draftURLs.map { url in
            URLQueryItem(name: "draft", value: url.lastPathComponent)
        }
        guard let actionURL = components.url else {
            onError(ShareResultError.URLInitError)
            return
        }
        openURL(actionURL)
        onSuccess()
    }
    
}

#Preview {
    ShareView(items: [], onSuccess: {}, onError: {_ in })
}
