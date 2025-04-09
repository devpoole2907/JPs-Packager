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
    @State private var selectedView: String? = "Home"

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedView) {
                Label("Home", systemImage: "house")
                    .tag("Home")
                Label("Logs", systemImage: "doc.plaintext")
                    .tag("Logs")
                Label("About", systemImage: "info.circle")
                    .tag("About")
            }
        } detail: {
            switch selectedView {
            case "Home":
                PackagerView()
                    .environmentObject(viewModel)
            case "Logs":
                LogsView()
                    .environmentObject(viewModel)
            case "About":
                AboutView()
            default:
                Text("Select a view")
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}


#Preview {
    ContentView()
}
