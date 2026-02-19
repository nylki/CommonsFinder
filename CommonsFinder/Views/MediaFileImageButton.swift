//
//  MediaFileImageButton.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.01.26.
//

import NukeUI
import SwiftUI

struct MediaFileImageButton: View {
    let mediaFileInfo: MediaFileInfo
    @Binding var isShowingFullscreenImage: Bool

    var body: some View {
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
}

#Preview {
    @Previewable @State var isShowing = false
    VStack {
        MediaFileImageButton(mediaFileInfo: .makeRandomUploaded(id: "abc", .horizontalImage), isShowingFullscreenImage: $isShowing)
    }
}
