//
//  UploadFilePreparationTests.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.08.26.
//

import CoreLocation
import Foundation
import Testing
import UIKit

/// Test non-destructive EXIF-overwriting (user-defined geolocation/disabled location)
@MainActor
@Suite("Upload File Preparation")
struct UploadFilePreparationTests {

    init() {
        // remove any dangling draft and staging files before running each test
        let stagingFiles: [URL]? = try? FileManager.default.contentsOfDirectory(
            at: MediaFileDraft.uploadStagingDirectory,
            includingPropertiesForKeys: nil
        )

        guard let stagingFiles else { return }

        for file in stagingFiles {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Creates a small JPEG with embedded GPS EXIF in the app Documents directory and returns a draft for it.
    private func createSampleDraft(latitude: Double, longitude: Double) throws -> MediaFileDraft {
        let renderer = UIGraphicsImageRenderer(size: .init(width: 8, height: 8))
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(.init(x: 0, y: 0, width: 8, height: 8))
        }

        let location = CLLocation(latitude: latitude, longitude: longitude)
        let fileItem = try FileItem(uiImage: image, metadata: NSDictionary(), location: location)
        return try MediaFileDraft(fileItem, isPartOfMultiDraft: false, newDraftOptions: nil)
    }

    private func cleanup(_ draft: MediaFileDraft) {
        if let original = draft.localFileURL() {
            try? FileManager.default.removeItem(at: original)
        }
    }


    @Test("Stripping location writes a staging copy and preserves the original file")
    func stripLocationPreservesOriginal() throws {
        var draft = try createSampleDraft(latitude: 48.137, longitude: 11.575)

        defer { cleanup(draft) }
        #expect(draft.loadCachedExifData()?.coordinate != nil, "the imported file must have a coordinate for this test")

        // setting `.noLocation` is expected to remove location EXIF data
        draft.locationHandling = .noLocation

        let uploadURL = try draft.preparedUploadFileURL()

        #expect(
            uploadURL != draft.localFileURL(),
            "upload url must not be the original import file url, otherwise the original gets overwritten."
        )
        #expect(FileManager.default.fileExists(atPath: uploadURL.path()), "file to upload should exist")

        #expect(draft.loadCachedExifData()?.coordinate != nil, "original draft file's EXIF should be unchanged")

        let stagingExif = try? ExifData(url: uploadURL)
        #expect(stagingExif?.coordinate == nil, "staging copy has EXIF location data removed")
    }

    @Test("Keeping EXIF location retains the original metadata")
    func exifLocationUsesOriginal() throws {
        let testLat = 48.137
        let testLon = 11.575
        var draft = try createSampleDraft(latitude: testLat, longitude: testLon)
        defer { cleanup(draft) }

        // setting `.exifLocation` is expected to keep the exif location intact and use it for structured metadata
        draft.locationHandling = .exifLocation

        let uploadURL = try draft.preparedUploadFileURL()

        #expect(FileManager.default.fileExists(atPath: uploadURL.path()), "file to upload should exist")

        let stagingExifData = try #require((try? ExifData(url: uploadURL))?.coordinate)

        #expect(stagingExifData.latitude == testLat)
        #expect(stagingExifData.longitude == testLon)
    }

    @Test("User-defined location writes the chosen coordinate into the staging copy")
    func userDefinedLocationWritesStaging() throws {
        let sampleLat = 10.0
        let sampleLon = 11.0
        var draft = try createSampleDraft(latitude: sampleLat, longitude: sampleLon)
        defer { cleanup(draft) }

        // setting `.locationHandling` with latitude, longitude is expected to only use those values for the wikitext and structured data
        // but not the EXIF GPS data. Those are expected to be removed to correctness.
        draft.locationHandling = .userDefinedLocation(latitude: 48.137, longitude: 11.575, precision: 0.0001)

        let uploadURL = try draft.preparedUploadFileURL()

        #expect(FileManager.default.fileExists(atPath: uploadURL.path()), "file to upload should exist")

        let originalDraftEXIFCoordinate = draft.loadCachedExifData()?.coordinate
        #expect(
            originalDraftEXIFCoordinate?.latitude == sampleLat && originalDraftEXIFCoordinate?.longitude == sampleLon,
            "original draft file should be untouched."
        )

        #expect(
            (try? ExifData(url: uploadURL))?.coordinate == nil,
            "We expect the EXIF GPS location to be removed when the user defined/refined a location for correctness and expectations: a user defined location is not a GPS-determined location and treating it as such can create misunderstandings in the context of public/commons files."
        )
    }
}
