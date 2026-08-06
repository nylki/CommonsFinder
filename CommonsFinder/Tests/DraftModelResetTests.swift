//
//  DraftModelResetTests.swift
//  CommonsFinderTests
//
//  Created by Tom Brewe on 06.08.26.
//

import CommonsAPI
import Foundation
import GRDB
import Testing

/// Covers the publishing-state reset behaviour of the draft models when a draft is saved:
/// edits invalidate a prior publishing attempt (so state/errors are reset), except for
/// already-published (sub-)drafts, and multi-draft edits are blocked while an upload runs.
@MainActor
@Suite("Draft Model Reset")
struct DraftModelResetTests {

    // MARK: - SingleDraftModel

    @Test("SingleDraftModel clears publishing error and state when saved after a failed upload")
    func singleDraftResetsFailedState() throws {
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        let repo = try AppDatabase(dbQueue)

        let draft = MediaFileDraft.makeRandomDraft(
            id: "failed-single-draft",
            publishingState: .uploaded(filekey: "some-file-key"),
            publishingError: .appQuitOrCrash
        )
        let model = SingleDraftModel(existingDraft: draft)

        try model.saveEditingChanges(appDatabase: repo)

        // The in-memory model is reset ...
        #expect(model.draft.publishingError == nil)
        #expect(model.draft.publishingState == nil)

        // ... and the reset is persisted.
        let persisted = try #require(
            try repo.reader.read { db in try MediaFileDraft.fetchOne(db, id: model.draft.id) },
            "We expect the edited draft to have been saved to the DB."
        )
        #expect(persisted.publishingError == nil)
        #expect(persisted.publishingState == nil)
    }

    @Test("SingleDraftModel clears an in-progress publishing state on save (even without an error)")
    func singleDraftResetsInProgressState() throws {
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        let repo = try AppDatabase(dbQueue)

        let draft = MediaFileDraft.makeRandomDraft(
            id: "in-progress-single-draft",
            publishingState: .uploading(0.5),
            publishingError: nil
        )
        let model = SingleDraftModel(existingDraft: draft)

        try model.saveEditingChanges(appDatabase: repo)

        // Any edit invalidates the prior attempt, so the in-progress state is wiped.
        #expect(model.draft.publishingState == nil)
    }

    @Test("SingleDraftModel throws and does not reset when the draft is already published")
    func singleDraftThrowsWhenAlreadyPublished() throws {
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        let repo = try AppDatabase(dbQueue)

        let draft = MediaFileDraft.makeRandomDraft(
            id: "published-sub-draft",
            publishingState: .published,
            publishingError: nil
        )
        let model = SingleDraftModel(existingDraft: draft)

        // Editing a published (sub-)draft is rejected, otherwise the multi-draft retry
        // filter would re-upload it and create a duplicate on Commons.
        #expect(throws: SingleDraftModelError.self) {
            try model.saveEditingChanges(appDatabase: repo)
        }

        // The `.published` marker is left intact by the early throw.
        #expect(model.draft.publishingState == .published)
    }

    // MARK: - MultiDraftModel

    @Test("MultiDraftModel clears the aggregate publishing state when saved after a finished upload")
    func multiDraftResetsFinishedState() throws {
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        let repo = try AppDatabase(dbQueue)

        var multiDraft = MultiDraft(newDraftOptions: nil)
        multiDraft.name = "Finished-with-errors multi draft"
        // A finished multi-upload where one sub-draft failed still ends with `isFinished == true`.
        multiDraft.publishingState = .init(overallProgress: 1, isFinished: true, completedCount: 1, totalCount: 2)

        let subDrafts = [
            MediaFileDraft.makeRandomDraft(id: "multi-sub-a", named: "multi-sub-a"),
            MediaFileDraft.makeRandomDraft(id: "multi-sub-b", named: "multi-sub-b"),
        ]
        let model = MultiDraftModel(MultiDraftInfo(multiDraft: multiDraft, drafts: subDrafts))


        try model.saveEditingChanges(appDatabase: repo)

        // The finished state is reset so a retry re-runs the upload pipeline.
        #expect(model.multiDraft.publishingState == nil)

        let id = try #require(model.multiDraft.id, "We expect the saved multi-draft to have an ID.")
        let persisted = try #require(
            try repo.fetchMultiDraftInfo(id: id),
            "We expect the edited multi-draft to have been saved to the DB."
        )
        #expect(persisted.multiDraft.publishingState == nil)
    }

    @Test("MultiDraftModel saves a fresh draft that has no publishing state")
    func multiDraftSavesWhenNoPublishingState() throws {
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        let repo = try AppDatabase(dbQueue)

        var multiDraft = MultiDraft(newDraftOptions: nil)
        multiDraft.name = "Fresh multi draft"

        let subDrafts = [
            MediaFileDraft.makeRandomDraft(id: "multi-sub-c", named: "multi-sub-c"),
            MediaFileDraft.makeRandomDraft(id: "multi-sub-d", named: "multi-sub-d"),
        ]
        let model = MultiDraftModel(MultiDraftInfo(multiDraft: multiDraft, drafts: subDrafts))

        try model.saveEditingChanges(appDatabase: repo)

        // With no publishing state the save proceeds normally.
        #expect(model.multiDraft.id != nil)
        #expect(model.multiDraft.publishingState == nil)
    }

    @Test("MultiDraftModel blocks edits while an upload is in progress")
    func multiDraftBlocksSaveWhileUploading() throws {
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        let repo = try AppDatabase(dbQueue)

        var multiDraft = MultiDraft(newDraftOptions: nil)
        multiDraft.name = "In-progress multi draft"
        multiDraft.publishingState = .init(overallProgress: 0.5, isFinished: false, completedCount: 1, totalCount: 2)

        let subDrafts = [
            MediaFileDraft.makeRandomDraft(id: "multi-sub-e", named: "multi-sub-e"),
            MediaFileDraft.makeRandomDraft(id: "multi-sub-f", named: "multi-sub-f"),
        ]
        let model = MultiDraftModel(MultiDraftInfo(multiDraft: multiDraft, drafts: subDrafts))

        #expect(throws: MultiDraftModelError.self) {
            try model.saveEditingChanges(appDatabase: repo)
        }

        // The guard returns early and throws an error: nothing is persisted and the in-progress state is untouched.
        #expect(model.multiDraft.id == nil, "We expect no DB write while an upload is in progress.")
        #expect(model.multiDraft.publishingState?.isFinished == false)
    }
}
