//
//  MultiDraftStatusSheet.swift
//  CommonsFinder
//
//  Created by Tom on 29.07.26.
//


import CommonsAPI
import GRDB
import SwiftUI
import os.log

extension View {
    @ViewBuilder
    func multiDraftStatusSheet(
        id: MultiDraft.MultiDraftID?,
        isPresented: Binding<Bool>,
        onEditDraft: @escaping () -> Void,
        onDeleteDraft: @escaping () -> Void,
        onContinueUpload: @escaping () -> Void
    ) -> some View {
        modifier(
            MultiDraftStatusSheetModifier(
                id: id,
                isPresented: isPresented,
                onEditDraft: onEditDraft,
                onDeleteDraft: onDeleteDraft,
                onContinueUpload: onContinueUpload
            )
        )
    }
}

private struct MultiDraftStatusSheetModifier: ViewModifier {
    let id: MultiDraft.MultiDraftID?
    @Binding var isPresented: Bool
    let onEditDraft: () -> Void
    let onDeleteDraft: () -> Void
    let onContinueUpload: () -> Void

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            NavigationStack {
                if let id {
                    MultiDraftStatusViewWrapper(
                        id: id,
                        onEditDraft: onEditDraft,
                        onDeleteDraft: onDeleteDraft,
                        onContinueUpload: onContinueUpload
                    )
                    .id(id)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

private struct MultiDraftStatusViewWrapper: View {
    let id: MultiDraft.MultiDraftID

    let onEditDraft: () -> Void
    let onDeleteDraft: () -> Void
    let onContinueUpload: () -> Void

    @Environment(\.appDatabase) private var appDatabase

    @State private var multiDraftInfo: MultiDraftInfo?


    var body: some View {
        NavigationStack {
            if let multiDraftInfo {
                MultiDraftStatusView(
                    multiDraftInfo: multiDraftInfo,
                    onEditDraft: onEditDraft,
                    onDeleteDraft: onDeleteDraft,
                    onContinueUpload: onContinueUpload
                )
            }
        }
        .task {
            do {
                let observation = ValueObservation.tracking { db in
                    try MultiDraftInfo.fetchOne(db, id: id)
                }

                for try await multiDraftInfo in observation.values(in: appDatabase.reader) {
                    try Task.checkCancellation()
                    self.multiDraftInfo = multiDraftInfo
                }
            } catch {
                logger.error("Failed to observe multiDraftInfo \(error)")
            }
        }

    }

}
private struct MultiDraftStatusView: View {
    let multiDraftInfo: MultiDraftInfo

    let onEditDraft: () -> Void
    let onDeleteDraft: () -> Void
    let onContinueUpload: () -> Void

    @Environment(\.appDatabase) private var appDatabase
    @Environment(UploadManager.self) private var uploadManager
    @Environment(\.dismiss) private var dismiss


    private var failedCount: Int {
        multiDraftInfo.drafts.count(where: { $0.publishingError != nil })
    }


    private var isContinuationPossible: Bool {
        multiDraftInfo.drafts.allSatisfy(\.publishingError.isContinuationPossible)
    }

    private var isUploadFinished: Bool {
        multiDraftInfo.multiDraft.publishingState?.isFinished ?? false
    }

    var body: some View {

        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading) {
                    ForEach(multiDraftInfo.drafts) { draft in
                        StatusListItem(draft: draft)
                    }
                }
            }
            .scenePadding([.horizontal, .top])
            .navigationBarTitle("Upload Status", displayMode: .inline)
            .toolbar {
                if isUploadFinished, failedCount >= 1, !uploadManager.isVerifyingErrorDrafts {
                    ToolbarItem(placement: .bottomBar) {
                        bottomToolbarButton
                    }

                    ToolbarItem {
                        Menu("More…", systemImage: "ellipsis") {
                            Button("Edit Draft", systemImage: "square.and.pencil", action: onEditDraft)
                            Button("Delete Draft", systemImage: "trash", role: .destructive, action: onDeleteDraft)
                        }
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", role: .cancel, action: dismiss.callAsFunction)
                }
            }
        }
        .onAppear {
            uploadManager.verifyDraftsWithErrors()
        }
    }


    @ViewBuilder
    private var bottomToolbarButton: some View {
        if uploadManager.isVerifyingErrorDrafts {
            ProgressView().progressViewStyle(.circular)
        } else if isContinuationPossible {
            Button(action: onContinueUpload) {
                HStack {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    Text("Retry all \(failedCount) failed files")
                }
                .padding()
            }
        } else {
            Button(role: .destructive, action: onDeleteDraft) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Draft")
                }
                .padding(10)
                .foregroundStyle(.red)
            }
        }
    }
}


private struct StatusListItem: View {

    let draft: MediaFileDraft
    @State private var isShowingIndividualErrorSheet = false

    var body: some View {
        Button {
            isShowingIndividualErrorSheet = true
        } label: {
            label
        }
        .buttonStyle(.plain)
        .animation(.default, value: draft)
        .publishingErrorDetailsSheet(
            draft.publishingState,
            draft.publishingError,
            isPresented: $isShowingIndividualErrorSheet,
            onEditDraft: {},
            onDeleteDraft: {},
            onContinueUpload: {}
        )
    }


    private var label: some View {
        HStack {
            BaseDraftImageView(draft: draft, size: .thumb)
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: 16))

            Spacer(minLength: 0)

            statusText
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        HStack {
            if let error = draft.publishingError {
                Text(error.description)
                Spacer(minLength: 0)
                Image(systemName: "exclamationmark.circle.fill")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .padding(.horizontal, 5)
                    .foregroundStyle(.red)

            } else if let publishingState = draft.publishingState {
                switch publishingState {
                case .uploading(let progress):
                    let percentCompleted = Int64(progress * 100)
                    Text("\(percentCompleted)% completed")
                    Spacer(minLength: 0)
                    CircularProgressShape(progress: progress)
                        .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 28, height: 28)
                        .padding(.horizontal, 5)

                case .uploaded(_), .unstashingFile(_), .creatingWikidataClaims:
                    Text("in progress")
                    Spacer(minLength: 0)
                    ProgressView().progressViewStyle(.circular)

                case .published:
                    Text("upload succesful")
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .padding(.horizontal, 5)
                        .foregroundStyle(.completed)


                }

            } else {
                Spacer(minLength: 0)
                ProgressView().progressViewStyle(.circular)
                    .frame(width: 28, height: 28)
                    .padding(.horizontal, 5)
            }
        }


    }
}


//#Preview(traits: .previewEnvironment) {
//    Color.clear.sheet(isPresented: .constant(true)) {
//        Navi
//    }
//}
