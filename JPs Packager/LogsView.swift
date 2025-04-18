//
//  LogsView.swift
//  JPs Packager
//
//  Created by James Poole on 09/04/2025.
//
import SwiftUI

struct LogsView: View {
    @EnvironmentObject var viewModel: PackagerViewModel

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "JPsPackagerLogs.txt"
        panel.begin { result in
            if result == .OK, let url = panel.url {
                do {
                    try viewModel.logs.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("❌ Failed to export logs: \(error.localizedDescription)")
                }
            }
        }
    }

    var body: some View {
        ScrollView {
            Text(viewModel.logs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
        .navigationTitle("Logs")
        .toolbar {
            ToolbarItem {
                Button("Export Logs") {
                    exportLogs()
                }
            }
        }
    }
}
