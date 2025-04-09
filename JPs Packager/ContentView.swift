//
//  ContentView.swift
//  JPs Packager
//
//  Created by James Poole on 09/04/2025.
//

import SwiftUI
import AppKit

class PackagerViewModel: ObservableObject {
    @AppStorage("sourceFolderPath") var sourceFolderPath: String = ""
    @AppStorage("outputFolderPath") var outputFolderPath: String = ""
    @AppStorage("packageIdentifier") var packageIdentifier: String = "com.tvnz.app"
    @AppStorage("packageVersion") var packageVersion: String = "1.0.0"
    @AppStorage("installLocation") var installLocation: String = "/Applications"
    @AppStorage("logs") var logs: String = ""
    @AppStorage("outputPackageName") var outputPackageName: String = "JPsOutput"
    @AppStorage("usePostinstallScript") var usePostinstallScript: Bool = false
    @Published var postinstallScript: String = "#!/bin/bash\n\n"

    func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }

    func openFolderPicker() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"

        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    func buildPackage(onComplete: @escaping (String) -> Void) {
        guard !sourceFolderPath.isEmpty,
              !outputFolderPath.isEmpty else {
            let errorMessage = "❌ Please select both source and output folders."
            self.logs += "[\(timestamp())] Error: \(errorMessage)\n"
            onComplete(errorMessage)
            return
        }

        let outputFilePath = "\(outputFolderPath)/\(outputPackageName).pkg"

        var arguments = [
            "--root", sourceFolderPath,
            "--identifier", packageIdentifier,
            "--version", packageVersion,
            "--install-location", installLocation
        ]

        var scriptTempDir: URL?

        if usePostinstallScript {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let scriptsDir = tempDir.appendingPathComponent("scripts")
            try? FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)

            let postinstallURL = scriptsDir.appendingPathComponent("postinstall")
            try? postinstallScript.write(to: postinstallURL, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: postinstallURL.path)

            arguments += ["--scripts", scriptsDir.path]
            scriptTempDir = tempDir
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pkgbuild")
        process.arguments = arguments + [outputFilePath]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                self.logs += "[\(timestamp())] \(output)\n"
            }
            if process.terminationStatus == 0 {
                let successMessage = "✅ Package built successfully at \(outputFilePath)"
                self.logs += "[\(timestamp())] \(successMessage)\n"
                onComplete(successMessage)
            } else {
                let failMessage = "❌ Package build failed. Check the Logs tab for more information."
                self.logs += "[\(timestamp())] \(failMessage)\n"
                onComplete(failMessage)
            }
        } catch {
            let errorOutput = "❌ Failed to run pkgbuild. Check the Logs tab for more information."
            self.logs += "[\(timestamp())] Error running pkgbuild: \(error.localizedDescription)\n"
            onComplete(errorOutput)
        }

        if let scriptTempDir = scriptTempDir {
            try? FileManager.default.removeItem(at: scriptTempDir)
        }
    }
}

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
            }
        } detail: {
            switch selectedView {
            case "Home":
                PackagerView()
                    .environmentObject(viewModel)
            case "Logs":
                LogsView()
                    .environmentObject(viewModel)
            default:
                Text("Select a view")
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct LogsView: View {
    @EnvironmentObject var viewModel: PackagerViewModel

    var body: some View {
        ScrollView {
            Text(viewModel.logs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
        .navigationTitle("Logs")
    }
}

struct PackagerView: View {
    
    @EnvironmentObject var viewModel: PackagerViewModel
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var confirmLargeFolder = false
    @State private var largeFolderSize: Int64 = 0
    @State private var isEditingScript = false
    
    var formattedLargeFolderSize: String {
        let sizeInGB = Double(largeFolderSize) / 1_000_000_000
        return String(format: "%.2f GB", sizeInGB)
    }
    
    private func folderPickerSection(title: String, path: String, action: @escaping () -> Void) -> some View {
        Section(header: Text(title)) {
            VStack(alignment: .leading) {
                Text(path.isEmpty ? "No folder selected" : path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Choose \(title)") {
                    action()
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private func runBuildPackage() {
        viewModel.buildPackage { message in
            alertMessage = message
            showAlert = true
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Form {
                    Section(header: Text("Package Info")) {
                        TextField("Package Identifier", text: $viewModel.packageIdentifier)
                            .textFieldStyle(.roundedBorder)
                        TextField("Version", text: $viewModel.packageVersion)
                            .textFieldStyle(.roundedBorder)
                        TextField("Install Location", text: $viewModel.installLocation)
                            .textFieldStyle(.roundedBorder)
                        TextField("Package Name", text: $viewModel.outputPackageName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Divider().padding(.vertical, 6)

                    folderPickerSection(title: "Source Folder", path: viewModel.sourceFolderPath) {
                        if let selected = viewModel.openFolderPicker() {
                            viewModel.sourceFolderPath = selected
                        }
                    }

                    folderPickerSection(title: "Output Folder", path: viewModel.outputFolderPath) {
                        if let selected = viewModel.openFolderPicker() {
                            viewModel.outputFolderPath = selected
                        }
                    }
                    
                    Divider().padding(.vertical, 6)
                    
                    Section(header: Text("Advanced")) {
                        Toggle("Include Postinstall Script", isOn: $viewModel.usePostinstallScript)
                            .padding(.bottom, 2)
                                   
                        if viewModel.usePostinstallScript {
                            
                            Text("Drag and drop one here or...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button("Edit Script…") {
                                isEditingScript = true
                            }
                        }
                    }

                    Section {
                        HStack {
                            Spacer()
                            Button("Build Package") {
                                let folderSize = getFolderSize(atPath: viewModel.sourceFolderPath)
                                largeFolderSize = folderSize
                                if folderSize > 1_000_000_000 {
                                    confirmLargeFolder = true
                                } else {
                                    runBuildPackage()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.sourceFolderPath.isEmpty || viewModel.outputFolderPath.isEmpty)
                            Spacer()
                        }
                    }
                }
            }
            .frame(maxWidth: 600)
            .padding()
        }
        
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            if let item = providers.first {
                _ = item.loadObject(ofClass: URL.self) { url, _ in
                    if let fileURL = url,
                       let contents = try? String(contentsOf: fileURL) {
                        DispatchQueue.main.async {
                            viewModel.postinstallScript = contents
                            viewModel.usePostinstallScript = true
                        }
                    }
                }
                return true
            }
            return false
        }
        
        .alert("Build Result", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("Large Folder", isPresented: $confirmLargeFolder) {
            Button("OK", role: .none) {
                runBuildPackage()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The selected source folder is larger than 1 GB (\(formattedLargeFolderSize)). Are you sure you want to continue?")
        }
        .navigationTitle("JPs Packager")
        .sheet(isPresented: $isEditingScript) {
            scriptEditorSheet()
        }
    }
    
    @ViewBuilder
    private func scriptEditorSheet() -> some View {
        VStack(alignment: .leading) {
            Text("Postinstall Script")
                .font(.headline)
                .padding(.top)

            TextEditor(text: $viewModel.postinstallScript)
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(minWidth: 600, minHeight: 400)

            HStack {
                Spacer()
                Button("Done") {
                    isEditingScript = false
                }
                .keyboardShortcut(.defaultAction)
                .padding()
            }
        }
        .padding()
    }
    
    func getFolderSize(atPath path: String) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else { return 0 }

        var totalSize: Int64 = 0

        for case let file as String in enumerator {
            let fullPath = (path as NSString).appendingPathComponent(file)
            if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
               let fileSize = attrs[.size] as? Int64 {
                totalSize += fileSize
            }
        }

        return totalSize
    }
}

#Preview {
    ContentView()
}
