//
//  PPPCView.swift
//  JPs Packager
//
//  Created by James Poole on 18/04/2025.
//

import SwiftUI

struct PPPCView: View {
    @EnvironmentObject var viewModel: PPPCViewModel

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        viewModel.presentAppPicker()
                    }) {
                        Image(systemName: "plus")
                    }

                    Button(action: {
                        viewModel.removeSelectedApp()
                    }) {
                        Image(systemName: "minus")
                    }
                }
                .padding()

                List(selection: $viewModel.selectedApp) {
                    ForEach(viewModel.apps) { app in
                        HStack {
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                            Text(app.displayName)
                        }
                        .tag(app)
                    }
                }
                .listStyle(.sidebar)
                .onDrop(of: [.fileURL], isTargeted: $viewModel.dropTargeted) { providers in
                    viewModel.handleDrop(providers: providers)
                }
            }
        } detail: {
            if let app = viewModel.selectedApp {
                HStack(alignment: .top, spacing: 12) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.displayName)
                            .font(.largeTitle)
                            .bold()
                            .padding(.bottom, 4)
                        selectableText(title: "App Path:", content: app.url.path)
                        selectableText(title: "Bundle ID:", content: app.bundleID)
                        selectableText(title: "Code Requirement:", content: app.codeRequirement, minHeight: 100)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            } else {
                Text("Drag apps on the left or select one")
                    .italic()
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 300)
        .navigationTitle("Privacy Preferences Policy Control Center")
    }

    @ViewBuilder
    private func selectableText(title: String, content: String, minHeight: CGFloat = 30) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 2)
            TextEditor(text: .constant(content))
                .font(.body)
                .frame(minHeight: minHeight, maxHeight: minHeight)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    PPPCView()
}

class PPPCViewModel: ObservableObject {
    @Published var apps: [AppInfo] = []
    @Published var selectedApp: AppInfo?
    @Published var dropTargeted = false

    func addApp(from url: URL) {
        let bid = getBundleID(from: url)
        let req = getCodeRequirement(from: url)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let info = AppInfo(url: url, bundleID: bid, codeRequirement: req, icon: icon)
        if !apps.contains(info) {
            apps.append(info)
        }
        if selectedApp == nil {
            selectedApp = info
        }
    }

    func removeSelectedApp() {
        if let selectedApp = selectedApp, let index = apps.firstIndex(of: selectedApp) {
            apps.remove(at: index)
            self.selectedApp = apps.isEmpty ? nil : apps.first
        }
    }

    func presentAppPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { result in
            if result == .OK, let url = panel.url {
                DispatchQueue.main.async {
                    self.addApp(from: url)
                }
            }
        }
    }

    func getBundleID(from url: URL) -> String {
        return Bundle(url: url)?.bundleIdentifier ?? "Unavailable"
    }

    func getCodeRequirement(from url: URL) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-dr", "-", url.path]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return "Error running codesign"
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if let line = output.components(separatedBy: "\n").first(where: { $0.contains("designated =>") }) {
            return line.replacingOccurrences(of: "designated =>", with: "").trimmingCharacters(in: .whitespaces)
        } else {
            return "Code requirement not found"
        }
    }

    func appName(for url: URL) -> String {
        return Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String ?? url.deletingPathExtension().lastPathComponent
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { object, _ in
            guard let url = object, url.pathExtension == "app" else { return }
            DispatchQueue.main.async {
                self.addApp(from: url)
            }
        }
        return true
    }
}
