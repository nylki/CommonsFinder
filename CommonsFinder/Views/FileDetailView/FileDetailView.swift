//
//  FileDetailView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 18.10.24.
//

import CommonsAPI
import FrameUp
import GRDB
import GeoToolbox
import Nuke
import NukeUI
import SwiftUI
import os.log

struct FileDetailView: View {
    // TODO: maybe convert to @Query (or other observation here) and upsert MediaFile into DB on .task and then do dbMediaFile ?? passedMediaFile

    init(_ initialMediaFileInfo: MediaFileInfo, namespace: Namespace.ID) {
        self.initialMediaFileInfo = initialMediaFileInfo
        self.navigationNamespace = namespace
    }

    private let initialMediaFileInfo: MediaFileInfo
    private let navigationNamespace: Namespace.ID
    @Namespace private var localNamespace

    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @Environment(Navigation.self) private var navigation
    @Environment(\.appDatabase) private var appDatabase
    @Environment(MapModel.self) private var mapModel
    @Environment(EditingManager.self) private var editingManager

    @State private var updatedMediaFileInfo: MediaFileInfo?
    private var mediaFileInfo: MediaFileInfo { updatedMediaFileInfo ?? initialMediaFileInfo }

    @State private var isShowingEditSheet = false
    @State private var isDescriptionExpanded = false

    @State private var isShowingFullscreenImage = false

    @State private var isResolvingTags = true
    @State private var resolvedTags: [TagItem] = []
    @State private var isShowingEditingError = false

    private var tagsHashID: String {
        "\(mediaFileInfo.mediaFile.categories.hashValue)-\(mediaFileInfo.mediaFile.statements.hashValue)"
    }


    private func saveFileToLastViewed() {
        do {
            updatedMediaFileInfo = try appDatabase.updateLastViewed(mediaFileInfo)
        } catch {
            logger.error("Failed to save media file as recently viewed. \(error)")
        }
    }

    private func updateBookmark(_ value: Bool) {
        do {
            let result = try appDatabase.updateBookmark(mediaFileInfo, bookmark: value)
            updatedMediaFileInfo = result
        } catch {
            logger.error("Failed to update bookmark on \(mediaFileInfo.mediaFile.name): \(error)")
        }
    }

    private var editingStatus: EditingStatus? {
        editingManager.status[mediaFileInfo.mediaFile.id]
    }

    private var editingError: Error? {
        editingStatus?.error
    }

    @concurrent
    private func refreshFromNetwork() async {
        do {
            guard
                let result = try await Networking.shared.api
                    .fetchFullFileMetadata(.pageids([mediaFileInfo.mediaFile.id])).first
            else {
                return
            }

            let refreshedMediaFile = MediaFile(apiFileMetadata: result)
            try await appDatabase.upsert([refreshedMediaFile])

            guard let refreshedMediaFileInfo = try await appDatabase.fetchMediaFileInfo(id: refreshedMediaFile.id) else {
                assertionFailure("MediaFileInfo nil although we just saved the underlying mediaFile.")
                return
            }

            let refreshedTags = try await refreshedMediaFile.resolveTags(appDatabase: appDatabase)

            await MainActor.run {
                self.updatedMediaFileInfo = refreshedMediaFileInfo
                self.resolvedTags = refreshedTags
            }

        } catch {
            logger.error("Failed to refresh media file \(error)")
        }
    }

    var body: some View {
        lazy var languageIdentifier = locale.wikiLanguageCodeIdentifier
        let navTitle = mediaFileInfo.mediaFile.localizedDisplayCaption ?? mediaFileInfo.mediaFile.displayName


        // Check view updates.
        // let _ = Self._printChanges()

        main
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .zoomableImageFullscreenCover(
                imageReference: mediaFileInfo.zoomableImageReference,
                isPresented: $isShowingFullscreenImage
            )
            .sheet(isPresented: $isShowingEditSheet) {
                FileEditView(mediaFileInfo: mediaFileInfo, resolvedTags: resolvedTags)
            }
            .alert("Failed to Publish", isPresented: $isShowingEditingError, presenting: editingError) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.localizedDescription)
            }
            .toolbar {
                ToolbarItem {
                    Button(
                        mediaFileInfo.isBookmarked ? "Remove Bookmark" : "Add Bookmark",
                        systemImage: mediaFileInfo.isBookmarked ? "bookmark.fill" : "bookmark"
                    ) {
                        updateBookmark(!mediaFileInfo.isBookmarked)
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button(
                            "View in Full Screen",
                            systemImage: "arrow.up.left.and.arrow.down.right.rectangle"
                        ) {
                            isShowingFullscreenImage = true
                        }

                        Button("Show on Map", systemImage: "map") {
                            navigation.showOnMap(mediaFile: mediaFileInfo.mediaFile, mapModel: mapModel)
                        }

                        Button("Edit", systemImage: "pencil") {
                            isShowingEditSheet = true
                        }
                        .disabled(editingStatus != nil || isResolvingTags)

                        Divider()

                        ShareLink(item: mediaFileInfo.mediaFile.descriptionURL)

                        Link(destination: mediaFileInfo.mediaFile.descriptionURL) {
                            Label("Open in Browser", systemImage: "globe")
                        }

                        Button {
                            UIPasteboard.general.string = mediaFileInfo.mediaFile.name
                        } label: {
                            Image(systemName: "clipboard")
                            Text("Copy Filename")
                            Text(mediaFileInfo.mediaFile.name)
                        }

                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .toolbar(removing: .title)
            .navigationTransition(.zoom(sourceID: mediaFileInfo.mediaFile.id, in: navigationNamespace))
            .task(id: mediaFileInfo.id) {
                do {
                    let id = mediaFileInfo.id
                    let observation = ValueObservation.tracking { db in
                        try MediaFile
                            //  required, because we update `lastViewed` above.
                            .including(optional: MediaFile.itemInteraction)
                            .filter(id: id)
                            .asRequest(of: MediaFileInfo.self)
                            .fetchOne(db)
                    }

                    for try await updatedMediaFileInfo in observation.values(in: appDatabase.reader) {
                        try Task.checkCancellation()

                        self.updatedMediaFileInfo = updatedMediaFileInfo
                    }
                } catch {
                    logger.error("CAT: Failed to observe MediaFileInfo changes \(error)")
                }
            }
            .task(priority: .high) {
                let timeIntervalSinceLastFetchDate = Date.now.timeIntervalSince(mediaFileInfo.mediaFile.fetchDate)
                //            logger.info("Time since last fetch: \(timeIntervalSinceLastFetchDate)")
                if timeIntervalSinceLastFetchDate > 20 {
                    await refreshFromNetwork()
                }
            }
            .task(id: tagsHashID, priority: .userInitiated) {
                isResolvingTags = true

                do {
                    logger.info("Resolving Tags...")
                    let start = Date.now
                    let tags = try await mediaFileInfo.mediaFile.resolveTags(appDatabase: appDatabase)
                    let tagsWhereFetchedAsync = Date.now.timeIntervalSince(start) > 0.1
                    withAnimation(tagsWhereFetchedAsync ? .default : nil) {
                        self.resolvedTags = tags
                        logger.info("Resolving Tags finished.")
                    }
                    isResolvingTags = false
                } catch is CancellationError {
                    logger.error("tags resolve cancelled.")
                } catch {
                    logger.error("Failed to resolve MediaFile tags: \(error)")
                    isResolvingTags = false
                }
            }
            .onDisappear {
                saveFileToLastViewed()
            }
            .onChange(of: editingStatus) {
                guard let editingStatus else { return }
                if editingStatus.error != nil {
                    isShowingEditingError = true
                }
            }
    }

    @ViewBuilder
    private var main: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading) {
                MediaFileImageButton(mediaFileInfo: mediaFileInfo, isShowingFullscreenImage: $isShowingFullscreenImage)
                    .frame(minWidth: 0, maxWidth: .infinity)
                detailsView
                    .padding(.horizontal)
            }
        }
        .animation(.default) { view in
            view
                .disabled(editingStatus == .editing)
                .opacity(editingStatus == .editing ? 0.5 : 1)
                .overlay {
                    if editingStatus == .editing {
                        ProgressView()
                    }
                }
        }
    }

    private var detailsView: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                if let caption = mediaFileInfo.mediaFile.localizedDisplayCaption {
                    Text(caption)
                        .font(.title3)
                        .bold()
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)
                } else {
                    Color.clear.frame(height: 1).contentShape(.rect)
                }
            }

            if let fullDescription = mediaFileInfo.mediaFile.attributedStringDescription {
                ViewThatFits(in: .vertical) {
                    if !isDescriptionExpanded {
                        Text(fullDescription)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(fullDescription)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .lineLimit(isDescriptionExpanded ? 999 : 5)
                            .padding(.bottom, 0)
                            .textSelection(.enabled)

                        Button(isDescriptionExpanded ? "show less…" : "show more…") {
                            isDescriptionExpanded.toggle()
                        }
                        .font(.caption)
                    }
                }
                .frame(maxHeight: isDescriptionExpanded ? .infinity : 150)
                .animation(.easeInOut, value: isDescriptionExpanded)
            }

            if let inceptionDate = mediaFileInfo.mediaFile.inceptionDate {
                Text(inceptionDate, style: .date)
                    .font(.caption)
                    .textSelection(.enabled)
            }

            tagSection

            if let coordinate = mediaFileInfo.mediaFile.coordinate {
                InlineMap(coordinate: coordinate, item: .mediaFile(mediaFileInfo.mediaFile))
            }


            VStack(alignment: .leading, spacing: 20) {
                licenseAndCopyright
                uploaderAndUploadDate
            }
            .padding(.vertical)
        }
    }

    @ViewBuilder
    private var imageView: some View {
        Button {
            isShowingFullscreenImage = true
        } label: {
            LazyImage(request: mediaFileInfo.largeResizedRequest) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if let thumbRequest = mediaFileInfo.thumbRequest {
                    LazyImage(request: thumbRequest) { phase in
                        Group {
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Color.clear
                            }
                        }
                        .overlay {
                            ProgressView().progressViewStyle(.circular)
                        }
                    }
                }
            }
        }
        .buttonStyle(ImageButtonStyle())
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(minHeight: 0, maxHeight: .infinity)
        .modifier(LandscapeOrientationModifier())
    }

    @ViewBuilder
    private var uploaderAndUploadDate: some View {
        // TODO: differentiate between creator and uploader if they differ
        VStack(alignment: .leading) {
            let userUploads = NavigationStackItem.userUploads(username: mediaFileInfo.mediaFile.username)
            NavigationLink(value: userUploads) {
                Label(mediaFileInfo.mediaFile.username, systemImage: "person.fill")
            }
            .bold()

            Text("uploaded \(mediaFileInfo.mediaFile.uploadDate, style: .relative) ago")
                .font(.caption)
        }
    }

    @ViewBuilder
    private var licenseAndCopyright: some View {
        VStack(alignment: .leading) {
            Text("License")
                .bold()
                .padding(.bottom, 2)


            // TODO: add more options when interacting with license, eg.
            // 1. sheet -> selectable field to copy attribution
            // 2. simple terms what is allowed (if CC license, otherwise indicate going to page to read license)
            // 3. optionally go to license website
            // eg. attribution might be missing from structured data, but its important for re-use
            // so we may have to use extMetadata "Attribution" which is more complete for legacy wikitext licensing
            Link(destination: mediaFileInfo.mediaFile.descriptionURL) {
                if let license = mediaFileInfo.mediaFile.primaryLicenseForDisplay {
                    Label {
                        ZStack {
                            switch license {
                            case .publicDomainLicense:
                                Text("Public Domain")
                            case .PDM_1_0:
                                Text("Public Domain")
                            case .CC0:
                                Text("CC0")
                            case .CC_BY_4_0, .CC_BY_3_0, .CC_BY_IGO_3_0, .CC_BY_2_5, .CC_BY_2_0, .CC_BY_1_0, .CC_BY_IGO_3_0:
                                Text("CC BY")
                            case .CC_BY_SA_4_0, .CC_BY_SA_3_0, .CC_BY_SA_IGO_3_0, .CC_BY_SA_2_5, .CC_BY_SA_2_0, .CC_BY_SA_1_0, .CC_BY_SA_IGO_3_0:
                                Text("CC BY-SA")
                            default:
                                if let rawAttribution = mediaFileInfo.mediaFile.rawAttribution {
                                    Text(rawAttribution)
                                        .multilineTextAlignment(.leading)
                                } else {
                                    Text("Other License")
                                }

                            }
                        }
                        .font(.callout)
                    } icon: {
                        HStack(spacing: -1) {
                            switch license {
                            case .CC0:
                                Image(.zeroSymbol)
                            case .publicDomainLicense:
                                EmptyView()
                            case .PDM_1_0:
                                Image(.pdSymbol)
                            case .CC_BY_4_0, .CC_BY_3_0, .CC_BY_IGO_3_0, .CC_BY_2_5, .CC_BY_2_0, .CC_BY_1_0, .CC_BY_IGO_3_0:
                                Image(.ccSymbol)
                                Image(.bySymbol)
                            case .CC_BY_SA_4_0, .CC_BY_SA_3_0, .CC_BY_SA_IGO_3_0, .CC_BY_SA_2_5, .CC_BY_SA_2_0, .CC_BY_SA_1_0, .CC_BY_SA_IGO_3_0:
                                Image(.ccSymbol)
                                Image(.bySymbol)
                                Image(.saSymbol)
                            default:
                                EmptyView()
                            }
                        }
                        .font(.system(size: 24))
                    }
                    .labelStyle(VerticalLabelStyle())
                } else if let copyright = mediaFileInfo.mediaFile.copyrightStatus {
                    switch copyright {
                    case .publicDomainCopyrightStatus:
                        Text("public domain")
                    case .copyrightedDedicatedToThePublicDomainByCopyrightHolder:
                        Text("copyrighted: dedicated to public domain")
                    case .copyrighted:
                        Text("copyrighted")
                    default:
                        Text("View License and Copyright Info")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tagSection: some View {

        ZStack {
            if isResolvingTags {
                let itemCount = mediaFileInfo.mediaFile.categories.count + mediaFileInfo.mediaFile.statements.map(\.isDepicts).count
                // TODO: better placeholder
                Color.clear.frame(height: Double(itemCount * 20))
                    .overlay(alignment: .top) {
                        ProgressView().progressViewStyle(.circular)
                    }
            } else {
                TagsContainerView(tags: resolvedTags)
            }
        }
        .animation(.default, value: isResolvingTags)

    }
}

struct LandscapeOrientationModifier: ViewModifier {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    func body(content: Content) -> some View {
        if verticalSizeClass != .regular {
            content
                .containerRelativeFrame(.vertical)
        } else {
            content

        }
    }
}

#Preview(traits: .previewEnvironment) {
    @Previewable @Namespace var namespace
    NavigationView {
        FileDetailView(
            .makeRandomUploaded(id: "Lorem Ipsum", .squareImage),
            namespace: namespace
        )
    }
}


struct VerticalLabelStyle: LabelStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        VStack {
            configuration.icon
            configuration.title

            Spacer()
        }
    }
}

// Moved for later reference:
//    @ViewBuilder
// FIXME: for wikidata items (aka Categories) use CategoryInfo to initialize
// eg. to be able to bookmark etc.
//    private func StatementListBox(_ values: [WikidataSnakValue]) -> some View {
//        lazy var languageIdentifier = locale.wikiLanguageCodeIdentifier
//
//        ScrollView(.horizontal) {
//            HStack {
//                ForEach(values, id: \.self) { value in
//                    ZStack {
//                        switch value {
//                        case .wikibaseEntityID(let item):
//                            let localizedLabel = categoryCache[item.id]?.base.label
//                            Text(localizedLabel ?? item.id)
//                                .animation(.default, value: localizedLabel)
//                        case .quantity(let quantity):
//                            quantityLabel(quantity)
//                        case .string(let string):
//                            Text(string)
//                        case .time(let dateValue):
//                            if let date = dateValue.date {
//                                Text(date, style: .date)
//                            }
//                        // location is handled separately
//                        default:
//                            Text("Unknown type of value")
//                        }
//                    }
//                    .bold()
//                    .padding(.horizontal, 15)
//                    .padding(.vertical, 10)
//                }
//            }
//        }
//    }

//    private func quantityLabel(_ quantity: WikidataClaim.Snak.DataValue.Quantity) -> Text {
//        var unitLabel = ""
//        if let unitID = quantity.unitID {
//            unitLabel = categoryCache[unitID.id]?.base.label ?? ""
//        }
//
//        let formatter = NumberFormatter()
//        formatter.minimumFractionDigits = 0
//        formatter.maximumFractionDigits = 2
//        formatter.minimumIntegerDigits = quantity.amountNumber < 1 ? 1 : 0
//        print("\(quantity.amountNumber) \(unitLabel)")
//
//        let amount = String(format: "%g", quantity.amountNumber)
//
//        return Text("\(amount) \(unitLabel)")
//    }
