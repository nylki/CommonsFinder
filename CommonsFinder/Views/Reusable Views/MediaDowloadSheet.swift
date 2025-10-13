////
////  MediaDowloadSheet.swift
////  CommonsFinder
////
////  Created by Tom Brewe on 11.10.25.
////
//
// Reference/Idea for later implementation together with complete attribution and license info
//import SwiftUI
//
//struct MediaDowloadSheet: View {
//    let mediaFileInfo: MediaFileInfo
//
//    @Environment(\.dismiss) private var dismiss
//
//    @State private var photoSaveProgress: PhotoSaveProgress?
//
//    enum PhotoSaveProgress: Identifiable, Equatable {
//        static func == (lhs: MediaDowloadSheet.PhotoSaveProgress, rhs: MediaDowloadSheet.PhotoSaveProgress) -> Bool {
//            lhs.id == rhs.id
//        }
//
//        case started
//        case finished
//        case error(Error)
//
//        var id: String {
//            switch self {
//            case .started:
//                "started"
//            case .finished:
//                "finished"
//            case .error(let error):
//                "error-\(error.localizedDescription)"
//            }
//        }
//
//
//    }
//
//    private func saveToPhotosLibrary() {
//        Task {
//            do {
//                photoSaveProgress = .started
//                try await mediaFileInfo.saveToPhotos()
//                photoSaveProgress = .finished
//            } catch {
//                photoSaveProgress = .error(error)
//            }
//        }
//    }
//
//
//    var body: some View {
//        NavigationStack {
//
//            VStack {
//
//                switch photoSaveProgress {
//                case .started:
//                    Label {
//                        Text("Saving...")
//                    } icon: {
//                        ProgressView()
//                    }
//                    .frame(minWidth: 0, maxWidth: .infinity)
//                    .padding(.vertical)
//
//                case .finished:
//                    Label("Saved to Photos Library", systemImage: "checkmark.circle.fill")
//                        .frame(minWidth: 0, maxWidth: .infinity)
//                        .padding(.vertical)
//                case .error(let error):
//                    Label {
//                        Text("Error: \(error.localizedDescription)")
//                    } icon: {
//                        Image(systemName: "arrow.down.app.dashed.trianglebadge.exclamationmark")
//                    }
//                    .frame(minWidth: 0, maxWidth: .infinity)
//                    .padding(.vertical)
//                case nil:
//                    Button {
//                        saveToPhotosLibrary()
//                    } label: {
//                        Label("save to Photos" , systemImage: "photo.stack")
//                            .frame(minWidth: 0, maxWidth: .infinity)
//                            .padding(.vertical)
//                    }
//
//                }
//
//
//
//
//
//                Button {
//
//                } label: {
//                    Label("download to Files", systemImage: "folder")
//                        .frame(minWidth: 0, maxWidth: .infinity)
//                        .padding(.vertical)
//                }
//                .disabled(true)
//
//                Spacer()
//
//                // FIXME: download attribution info here on demand if not inside structured data!!!!!
//                // AND READ FROM STRUCTURED DATA THE LICENSE AND ATTRIBUTION
//                if let rawAttribution = mediaFileInfo.mediaFile.rawAttribution {
//                    Divider()
//                    Button {
//                        UIPasteboard.general.string = mediaFileInfo.mediaFile.rawAttribution
//                    } label: {
//                        Label("copy attribution info", systemImage: "clipboard")
//                            .frame(minWidth: 0, maxWidth: .infinity)
//                            .padding(.vertical)
//
//                    }
//
//                    ScrollView(.vertical) {
//                        Text(rawAttribution)
//                            .textSelection(.enabled)
//                            .multilineTextAlignment(.leading)
//                    }
//                }
//            }
//            .scenePadding()
//            .glassButtonStyle()
//            .sensoryFeedback(trigger: photoSaveProgress) { oldValue, newValue in
//                guard oldValue != newValue else {
//                    return nil
//                }
//                return switch newValue {
//                    case .none, .started: nil
//                    case .error(_): .error
//                    case .finished: .success
//                }
//            }
//
//
//        }
//        .ignoresSafeArea()
//        .presentationDetents([.fraction(0.4)])
//
//    }
//}
//
//struct MediaDownloadSheetModifier: ViewModifier {
//    @Binding var item: MediaFileInfo?
//    func body(content: Content) -> some View {
//        content
//            .sheet(item: $item) {
//                MediaDowloadSheet(mediaFileInfo: $0)
//            }
//    }
//}
//
//
//extension View {
//    func mediaDownloadSheet(for mediaFileInfoBinding: Binding<MediaFileInfo?>) -> some View {
//        modifier(MediaDownloadSheetModifier(item: mediaFileInfoBinding))
//    }
//}
//
//#Preview {
//    @Previewable @State var mediaFileInfo: MediaFileInfo?
//    Button("download") {
//        mediaFileInfo = .makeRandomUploaded(id: "1", .verticalImage)
//    }
//    .mediaDownloadSheet(for: $mediaFileInfo)
//}
