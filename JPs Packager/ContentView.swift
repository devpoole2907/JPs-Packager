//
//  ContentView.swift
//  JPs Packager
//
//  Created by James Poole on 09/04/2025.
//

import SwiftUI
import AppKit



struct ContentView: View {
    @StateObject private var viewModel = PackagerViewModel()
    @StateObject private var pppcViewModel = PPPCViewModel()
    @State private var selectedView: String? = "Home"

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedView) {
                Label("Packaging", systemImage: "cube.box")
                    .tag("Packaging")
                Label("Logs", systemImage: "doc.plaintext")
                    .tag("Logs")
                Label("PPPC", systemImage: "lock")
                    .tag("PPPC")
                Label("About", systemImage: "info.circle")
                    .tag("About")
            }
        } detail: {
            switch selectedView {
            case "Packaging":
                PackagerView()
                    .environmentObject(viewModel)
            case "Logs":
                LogsView()
                    .environmentObject(viewModel)
            case "PPPC":
                PPPCView()
                    .environmentObject(pppcViewModel)
            case "About":
                AboutView()
            default:
                Text("Select a view")
            }
        }
        .frame(minWidth: 1000, minHeight: 600)
    }
}


#Preview {
    ContentView()
}
