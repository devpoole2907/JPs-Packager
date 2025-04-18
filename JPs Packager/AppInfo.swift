//
//  AppInfo.swift
//  JPs Packager
//
//  Created by James Poole on 18/04/2025.
//

import SwiftUI

final class AppInfo: ObservableObject, Identifiable, Equatable, Hashable {
    let id = UUID()
    let url: URL
    let bundleID: String
    let codeRequirement: String
    let icon: NSImage

    @Published var permissions: [PPPCPermission] = []
    
    init(url: URL,
         bundleID: String,
         codeRequirement: String,
         icon: NSImage,
         permissions: [PPPCPermission]) {
        self.url = url
        self.bundleID = bundleID
        self.codeRequirement = codeRequirement
        self.icon = icon
        self.permissions = permissions
    }

    var displayName: String {
        Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String ?? url.deletingPathExtension().lastPathComponent
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
