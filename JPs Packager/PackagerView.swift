//
//  PackagerView.swift
//  JPs Packager
//
//  Created by James Poole on 09/04/2025.
//

import SwiftUI

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
