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

//struct ___FileShowView: View {
//    private let navigationNamespace: Namespace.ID
//
//    // To make this a bit more minimal only one  non-optional @State MediaFile that gets the initial value initialized in Init?
//    // -> but that is considered bad practice, because it can be confusing that State is only set once in an init...
//    // But might be alright here, when stated that it is intended....
//    private let _initialMediaFileInfo: MediaFileInfo
//    @State private var _updatedMediaFileInfo: MediaFileInfo?
//    private var mediaFileInfo: MediaFileInfo { _updatedMediaFileInfo ?? _initialMediaFileInfo }
//    @State private var isShowingEditSheet: MediaFileInfo?
//    @Environment(\.appDatabase) private var appDatabase
//
//    init(_ mediaFileInfo: MediaFileInfo, navigationNamespace: Namespace.ID) {
//        // The immutable MediaFile is wrapped as an @Observable MediaFileModel here, to allow
//        // registering changes when user edits the file.
//        logger.debug("FileShowView Init")
//        _initialMediaFileInfo = mediaFileInfo
//        self.navigationNamespace = navigationNamespace
//    }
//
//    var body: some View {
//        MainFileShowView(mediaFileInfo: mediaFileInfo, navigationNamespace: navigationNamespace, onUpdateBookmark: updateBookmark)
//
//    }
//}


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
    @Environment(SearchModel.self) private var searchModel
    @Environment(\.isPresented) private var isPresented
    @Environment(\.appDatabase) private var appDatabase

    @State private var updatedMediaFileInfo: MediaFileInfo?
    private var mediaFileInfo: MediaFileInfo { updatedMediaFileInfo ?? initialMediaFileInfo }

    @State private var isShowingEditSheet: MediaFileInfo?
    @State private var fullDescription: AttributedString?
    @State private var isDescriptionExpanded = false

    @State private var isShowingFullscreenImage = false

    @State private var resolvedTags: [TagItem] = []

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


    @concurrent
    private func refreshFromNetwork() async {
        do {
            guard
                let result = try await CommonsAPI.API()
                    .fetchFullFileMetadata(fileNames: [mediaFileInfo.mediaFile.apiName]).first
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
            .fullscreenImageCover(mediaFileInfo: mediaFileInfo, namespace: localNamespace, isPresented: $isShowingFullscreenImage)
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
                        ShareLink(item: mediaFileInfo.mediaFile.descriptionURL)
                        Link(destination: mediaFileInfo.mediaFile.descriptionURL) {
                            Label("Open in Browser", systemImage: "globe")
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
            .task(id: mediaFileInfo.mediaFile.fullDescriptions, priority: .userInitiated) {
                if let attributedString = mediaFileInfo.mediaFile.createAttributedStringDescription(locale: locale) {
                    fullDescription = attributedString
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
                do {
                    logger.info("Resolving Tags...")
                    let start = Date.now
                    let tags = try await mediaFileInfo.mediaFile.resolveTags(appDatabase: appDatabase)
                    let tagsWhereFetchedAsync = Date.now.timeIntervalSince(start) > 0.1
                    withAnimation(tagsWhereFetchedAsync ? .default : nil) {
                        self.resolvedTags = tags
                        logger.info("Resolving Tags finished.")
                    }

                    //                    if let coordinate = mediaFileInfo.mediaFile.coordinate {


                    // NOTE: the following is unreliably and will skew the lookaround view
                    // if it is eg. just the Wikidata item of a street
                    // potential fix: only use wikidata items if they have a street adress (P6375) or "fullAddress" and use that address as well as the label
                    //                        let clLocation = CLLocation(
                    //                            latitude: coordinate.latitude,
                    //                            longitude: coordinate.longitude
                    //                        )
                    //                        let closestWikidataCategory = resolvedTags.map(\.baseItem)
                    //                            .sorted(by: { a, b in
                    //                                sortCategoriesByDistance(to: clLocation, a: a, b: b)
                    //                            }).first
                    //
                    //                        let commonName = closestWikidataCategory?.label ?? closestWikidataCategory?.commonsCategory

                    //                        placeDescriptor = PlaceDescriptor(
                    //                            representations: [.coordinate(coordinate)],
                    //                            commonName: nil
                    //                        )
                    //                    }

                } catch {
                    logger.error("Failed to resolve MediaFile tags: \(error)")
                }
            }
            .onDisappear {
                saveFileToLastViewed()
            }
    }

    @ViewBuilder
    private var main: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading) {
                HStack {
                    Spacer(minLength: 0)
                    imageView
                    Spacer(minLength: 0)
                }

                ZStack {
                    if let caption = mediaFileInfo.mediaFile.localizedDisplayCaption {
                        Text(caption)
                            .font(.title3)
                            .bold()
                            .multilineTextAlignment(.leading)
                    } else {
                        Color.clear.frame(height: 1).contentShape(.rect)
                    }
                }

                if let fullDescription {
                    ViewThatFits(in: .vertical) {
                        if !isDescriptionExpanded {
                            Text(fullDescription)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(fullDescription)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                                .lineLimit(isDescriptionExpanded ? 999 : 5)
                                .padding(.bottom, 0)

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
                    Text(inceptionDate, style: .date).font(.caption)
                }

                tagSection

                if let coordinate = mediaFileInfo.mediaFile.coordinate {
                    InlineMap(coordinate: coordinate)
                }


                VStack(alignment: .leading, spacing: 20) {
                    licenseAndCopyright
                    uploaderAndUploadDate
                }
                .padding(.vertical)
            }
            .padding([.horizontal, .bottom])
        }
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
        let itemCount = mediaFileInfo.mediaFile.categories.count + mediaFileInfo.mediaFile.statements.map(\.isDepicts).count
        if !resolvedTags.isEmpty {
            TagsContainerView(tags: resolvedTags)
        } else if itemCount > 0 {
            // TODO: better placeholder
            Color.clear.frame(height: Double(itemCount * 30))
                .overlay {
                    ProgressView().progressViewStyle(.circular)
                }
        }
    }

    @ViewBuilder
    private var imageView: some View {
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
        .containerRelativeFrame(.horizontal)
        .clipped()
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(minHeight: 0, maxHeight: .infinity)
        .modifier(FullscreenOnRotate())
        .onTapGesture {
            withAnimation {
                isShowingFullscreenImage = true
            }
        }
    }

}

struct FullscreenOnRotate: ViewModifier {
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

nonisolated extension WikidataItemID {
    static let preferredLicenses: [WikidataItemID] = [
        .CC0, .CC_BY_4_0, .CC_BY_SA_4_0, PDM_1_0,
    ]

    static let acceptableLicenses: [WikidataItemID] = [
        CC0,
        PDM_1_0,
        CC_BY_4_0,
        CC_BY_3_0,
        CC_BY_IGO_3_0,
        CC_BY_2_5,
        CC_BY_1_0,
        CC_BY_2_0,
        CC_BY_SA_4_0,
        CC_BY_SA_3_0,
        CC_BY_SA_IGO_3_0,
        CC_BY_SA_2_5,
        CC_BY_SA_2_0,
        CC_BY_SA_1_0,
    ]
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
