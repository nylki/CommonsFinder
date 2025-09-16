////
////  AuthNavigation.swift
////  CommonsFinder
////
////  Created by Tom Brewe on 12.11.24.
////
//
//import Foundation
//import SwiftUI
//
enum AuthNavigationDestination: Int, Hashable, Identifiable, Sendable {
    case onboardingChoice
    case login
    case register

    var id: Int { rawValue }
}
//
//@Observable final class AuthNavigationModel {
//    private(set) var path: [AuthNavigationDestination] = []
//}
