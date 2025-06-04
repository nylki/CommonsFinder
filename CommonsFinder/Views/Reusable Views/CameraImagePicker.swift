//
//  CameraImagePicker.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 22.04.25.
//

import SwiftUI
import UIKit

struct CameraImagePicker: UIViewControllerRepresentable {
    let onImage: (UIImage, _ metadata: NSDictionary) -> Void

    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> some UIViewController {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .camera
        imagePicker.cameraCaptureMode = .photo
        imagePicker.delegate = context.coordinator
        imagePicker.imageExportPreset = .compatible
        return imagePicker
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraImagePicker

        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage, let metadata = info[.mediaMetadata] as? NSDictionary {
                parent.onImage(uiImage, metadata)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
