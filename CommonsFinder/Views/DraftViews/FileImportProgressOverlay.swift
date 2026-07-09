//
//  FileImportProgressOverlay.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 02.07.26.
//

import Foundation
import SwiftUI

struct FileImportProgressOverlayModifier: ViewModifier {
    struct Options: Equatable, Hashable {
        let value: Int
        let total: Int?
    }

    let options: Options?
    let onCancel: () -> Void

    func body(content: Content) -> some View {
        let disabledParent = options != nil

        content
            .allowsHitTesting(!disabledParent)
            .disabled(disabledParent)
            .blur(radius: disabledParent ? 5 : 0)
            .overlay {
                if let options {
                    FileImportProgressOverlay(value: options.value, total: options.total, onCancel: onCancel)
                }
            }
            .animation(.default, value: options == nil)
    }
}

private struct FileImportProgressOverlay: View {
    let value: Int
    let total: Int?
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Preparing...")
                .bold()
                .padding(.horizontal)

            if let total {
                ProgressView(value: Double(value), total: Double(total)) {
                    Text("\(value) of \(total) files imported.")
                        .padding(.vertical)
                }
                .padding(.horizontal)
            } else {
                ProgressView()
            }
        }
        .padding()
        .safeAreaInset(edge: .bottom) {
            Button(action: onCancel) {
                Text("Cancel")
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .glassButtonStyle()
            .padding()
        }
        .fallbackGlassEffect(in: .rect(cornerRadius: 36, style: .circular))
        .geometryGroup()
        .compositingGroup()
        .scenePadding()
    }

}


#Preview {
    @Previewable @State var options: FileImportProgressOverlayModifier.Options? = .init(value: 5, total: 10)
    ZStack {
        Color.gray
        VStack {
            Button("Sould not be tappable") {
                print("should not print")
            }
            .glassButtonStyle()
            Spacer()
        }
        .padding()
    }
    .modifier(
        FileImportProgressOverlayModifier(
            options: .init(value: 5, total: 10),
            onCancel: {
                print("on cancel")
                options = nil
            })
    )
}
