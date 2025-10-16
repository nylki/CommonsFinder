//
//  ResolutionButton.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 14.10.25.
//

import SwiftUI
import TipKit
import os.log

struct ResolutionButton: View {
    let mediaFileInfo: MediaFileInfo
    let loadedImage: LoadedImageType
    let networkStatus: NetworkStatus
    let originalImageLoadedPercent: Int?

    let onLoadOriginalImage: () -> Void

    @State private var isShowingOriginalLoadConfirmation = false

    var body: some View {

        let manualDownloadEnabled = !loadedImage.isOriginal && networkStatus == .restricted && originalImageLoadedPercent == nil
        let shouldShowIcon = (!loadedImage.isOriginal && originalImageLoadedPercent != nil) || manualDownloadEnabled
        let fullImageLoadingTip = FullImageLoadingTip(isNetworkRestricted: manualDownloadEnabled)
        let horizontalPadding = 17.0

        Button {
            if manualDownloadEnabled {
                isShowingOriginalLoadConfirmation = true
            }
        } label: {
            HStack(spacing: 7) {
                resolutionInfoText

                if shouldShowIcon {
                    indicatorIcon
                        .transition(.offset(x: -horizontalPadding).combined(with: .scale).combined(with: .opacity))
                }
            }
            .padding(.leading, horizontalPadding)
            .padding(.trailing, !shouldShowIcon ? horizontalPadding : 0)
        }
        .buttonStyle(ZoomHUDButtonStyle())
        .geometryGroup()
        .compositingGroup()
        .popoverTip(fullImageLoadingTip)
        .confirmationDialog("Load original image", isPresented: $isShowingOriginalLoadConfirmation) {
            Button("load original image", role: .fallbackConfirm) {
                FullImageLoadingTip.didLoadFullImageManually.sendDonation()
                onLoadOriginalImage()
            }
        } message: {
            let byteStyle = ByteCountFormatStyle(style: .file, allowedUnits: [.kb, .mb, .gb, .tb])
            let fileSizeString: String =
                if let byte = mediaFileInfo.mediaFile.size {
                    byteStyle.format(Int64(byte))
                } else {
                    "unknown"
                }

            let dimensionString: String =
                if let w = mediaFileInfo.mediaFile.width, let h = mediaFileInfo.mediaFile.height {
                    "(\(w)×\(h)px)"
                } else {
                    ""
                }

            Text("Load original image \(dimensionString) with a size of \(fileSizeString) now?")
        }
        .animation(.default, value: networkStatus)
        .animation(.default, value: shouldShowIcon)
    }

    @ViewBuilder private var resolutionInfoText: some View {
        VStack(spacing: 1) {
            if loadedImage != .none,
                let width = loadedImage.width,
                let height = loadedImage.height
            {
                Group {
                    switch loadedImage {
                    case .none, .thumbnail(_):
                        Text("thumbnail")
                    case .resized(_):
                        Text("resized")
                    case .original(_, let isFromCache):
                        Text("original\(isFromCache ? " (cache)" : "")")

                    }
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))

                Text("\(width)×\(height) pixel")
                    .font(.subheadline)
            }
        }
        .animation(.default, value: loadedImage)
    }

    @ViewBuilder
    private var indicatorIcon: some View {
        let showProgressIndicator = originalImageLoadedPercent != nil
        Circle()
            .fill(.clear)
            .overlay {
                Image(systemName: showProgressIndicator ? "arrow.down" : "exclamationmark.circle")
                    .font(.system(size: showProgressIndicator ? 15 : 30))
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.pulse, isActive: showProgressIndicator)
            }
            .overlay {
                if let originalImageLoadedPercent {
                    CircularProgressShape(progress: Double(originalImageLoadedPercent) / 100)
                        .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .foregroundStyle(.white)
                        .animation(.linear, value: originalImageLoadedPercent)
                        .padding(11)
                }
            }
    }
}

struct ZoomHUDButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(height: 50)
            .background(Color.init(white: 0.1), in: .capsule)
            .clipShape(.capsule)
            .shadow(color: .white.opacity(0.7), radius: configuration.isPressed ? 5 : 1)
            .foregroundStyle(.white)
            .animation(.default) {
                $0.scaleEffect(configuration.isPressed ? 0.95 : 1)
            }

    }
}

#Preview {
    VStack {
        ResolutionButton(
            mediaFileInfo: .makeRandomUploaded(id: "1", .squareImage),
            loadedImage: .resized(.zeroSymbol),
            networkStatus: .ok,
            originalImageLoadedPercent: nil
        ) {

        }

        ResolutionButton(
            mediaFileInfo: .makeRandomUploaded(id: "1", .squareImage),
            loadedImage: .resized(.zeroSymbol),
            networkStatus: .restricted,
            originalImageLoadedPercent: nil
        ) {

        }

        ResolutionButton(
            mediaFileInfo: .makeRandomUploaded(id: "1", .squareImage),
            loadedImage: .resized(.zeroSymbol),
            networkStatus: .restricted,
            originalImageLoadedPercent: 30
        ) {

        }


        ResolutionButton(
            mediaFileInfo: .makeRandomUploaded(id: "1", .squareImage),
            loadedImage: .resized(.zeroSymbol),
            networkStatus: .restricted,
            originalImageLoadedPercent: 74
        ) {

        }

        ResolutionButton(
            mediaFileInfo: .makeRandomUploaded(id: "1", .squareImage),
            loadedImage: .original(.zeroSymbol, cached: false),
            networkStatus: .restricted,
            originalImageLoadedPercent: nil
        ) {

        }

        ResolutionButton(
            mediaFileInfo: .makeRandomUploaded(id: "1", .squareImage),
            loadedImage: .original(.zeroSymbol, cached: true),
            networkStatus: .restricted,
            originalImageLoadedPercent: nil
        ) {

        }
    }
    .containerRelativeFrame(.vertical)
    .containerRelativeFrame(.horizontal)
    .ignoresSafeArea()
    .background(Gradient(stops: [.init(color: .black, location: 0), .init(color: .white, location: 1)]))

}
