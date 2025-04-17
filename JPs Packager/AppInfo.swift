//
//  AppInfo.swift
//  JPs Packager
//
//  Created by James Poole on 18/04/2025.
//

import SwiftUI

struct AppInfo: Identifiable, Equatable, Hashable {
    let id = UUID()
    let url: URL
    let bundleID: String
    let codeRequirement: String
    let icon: NSImage

    var displayName: String {
        Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String ?? url.deletingPathExtension().lastPathComponent
    }
}
