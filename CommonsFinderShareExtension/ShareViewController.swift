//
//  ShareViewController.swift
//  CommonsFinderShareExtension
//
//  Created by Tom Brewe on 03.02.25.
//

import UIKit
//import Social
import SwiftUI

enum ShareError: Error {
    case missingItems
    case failedToLoadFileRepresentation
    case failedToGetAppGroupContainer
}

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        loadShareView()
    }

    var hostingController: UIHostingController<ShareView>?
    
    private func loadShareView() {
        guard let items = loadItems(), !items.isEmpty else {
            extensionContext?.cancelRequest(withError: ShareError.missingItems)
            return
        }
        
        view.backgroundColor = UIColor.clear
        view.isOpaque = false
        modalPresentationStyle = .overCurrentContext
        
        let rootView = ShareView(items: items,
            onSuccess: {
            self.extensionContext?.completeRequest(returningItems: nil)
        }, onError: { error in
            self.extensionContext?.cancelRequest(withError: error)
        })
        let hostingController = UIHostingController(rootView: rootView)
        self.addChild(hostingController)
        self.view.addSubview(hostingController.view)
        
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = UIColor.clear
        hostingController.view.isOpaque = false
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            hostingController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            hostingController.view.heightAnchor.constraint(equalToConstant: 360)
        ])
        
//        Task { @MainActor in
//            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
//            hostingController.view.topAnchor.constraint (equalTo: self.view.topAnchor).isActive = true
//            hostingController.view.bottomAnchor.constraint (equalTo: self.view.bottomAnchor).isActive = true
//            hostingController.view.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
//            hostingController.view.rightAnchor.constraint (equalTo: self.view.rightAnchor).isActive = true
//        }

//            hostingController.view.heightAnchor.constraint(equalToConstant: 360).isActive = true

//            modalPresentationStyle = .formSheet
//            modalTransitionStyle = .partialCurl
            
            hostingController.didMove(toParent: self)
        self.hostingController = hostingController
    }
    
    
    
    private func loadItems() -> [NSItemProvider]? {
        let items = extensionContext?.inputItems
            .compactMap { ($0 as? NSExtensionItem)?.attachments }
            .flatMap { $0 }
        
        return items
    }
}
