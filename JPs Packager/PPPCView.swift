//
//  PPPCView.swift
//  JPs Packager
//
//  Created by James Poole on 18/04/2025.
//

import SwiftUI

enum PPPCAuth: String, CaseIterable, Codable, Identifiable {
    case none = ""
    case allow = "Allow"
    case deny = "Deny"
    case allowStandardUserToSetSystemService = "AllowStandardUserToSetSystemService"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "-"
        case .allow: return "Allow"
        case .deny: return "Deny"
        case .allowStandardUserToSetSystemService: return "Allow Standard Users to Approve"
        }
    }
}

struct PPPCPermission: Identifiable, Hashable, Codable {
    let id = UUID()
    var service: String
    var auth: PPPCAuth = .none
    var comment: String = ""
    
    enum CodingKeys: String, CodingKey {
        case service
        case auth
        case comment
    }

    var displayName: String {
        pppcServiceDisplayNames[service] ?? service
    }
}

let pppcServiceDisplayNames: [String: String] = [
    "Accessibility": "Accessibility",
    "SystemPolicySysAdminFiles": "Admin Files",
    "Calendar": "Calendars",
    "Camera": "Camera",
    "AddressBook": "Contacts",
    "SystemPolicyDesktopFolder": "Desktop Folder Access",
    "SystemPolicyDocumentsFolder": "Documents Folder Access",
    "SystemPolicyDownloadsFolder": "Downloads Folder Access",
    "FileProviderPresence": "File Provider Presence",
    "SystemPolicyAllFiles": "Full Disk Access",
    "ListenEvent": "Input Monitoring",
    "MediaLibrary": "Media Library",
    "Microphone": "Microphone",
    "SystemPolicyNetworkVolumes": "Network Volumes",
    "Photos": "Photos",
    "PostEvent": "Post Events",
    "Reminders": "Reminders",
    "SystemPolicyRemovableVolumes": "Removable Volumes",
    "ScreenCapture": "Screen Recording",
    "SpeechRecognition": "Speech Recognition"
]

struct PPPCView: View {
    @EnvironmentObject var viewModel: PPPCViewModel
    @State private var permissionsExpanded = true
    @State private var selectedAppID: UUID?
    @State private var showExportSheet = false
    @State private var pendingImportURL: URL?
    @State private var showImportConfirmation = false

    private var selectedApp: AppInfo? {
        if let id = selectedAppID {
            return viewModel.apps.first { $0.id == id }
        }
        return nil
    }

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
                        if let app = selectedApp {
                            viewModel.remove(app: app)
                            // update selection
                            selectedAppID = viewModel.apps.first?.id
                        }
                    }) {
                        Image(systemName: "minus")
                    }
                }
                .padding()

                if viewModel.apps.isEmpty {
                    VStack {
                        Spacer()
                        Text("Drag apps here to inspect their permissions")
                            .italic()
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding()
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                  } else {
                    List(selection: $selectedAppID) {
                        ForEach(viewModel.apps) { app in
                            HStack {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                Text(app.displayName)
                            }
                            .tag(app.id)
                        }
                    }
                    .listStyle(.sidebar)
                }
            }
        } detail: {
            ZStack {
                if let app = selectedApp {
                    PPPCDetailView(app: app, permissionsExpanded: $permissionsExpanded)
                } else {
                    Text("Select an app to view its Privacy Preferences, or drag and drop a mobileconfig file here")
                        .italic()
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .frame(maxHeight: .infinity)
        }
        .onDrop(of: [.fileURL], isTargeted: .constant(false)) { providers in
            var handled = false

            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { object, _ in
                    guard let url = object else { return }
                    DispatchQueue.main.async {
                        let ext = url.pathExtension.lowercased()
                        if ext == "app" {
                            _ = viewModel.handleAppDrop(providers: [provider])
                        } else if ext == "mobileconfig" {
                            _ = viewModel.handleConfigDrop(
                                providers: [provider],
                                setPendingURL: { pendingImportURL = $0 },
                                triggerConfirmation: { showImportConfirmation = true }
                            )
                        }
                    }
                }
                handled = true
            }

            return handled
        }
        .frame(minWidth: 600, minHeight: 300)
        .navigationTitle("Privacy Preferences Policy Control Center")
        .toolbar {
            ToolbarItemGroup {
                Button("Import") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.init(filenameExtension: "mobileconfig")!]
                    panel.canChooseFiles = true
                    panel.allowsMultipleSelection = false
                    panel.begin { result in
                        if result == .OK, let url = panel.url {
                            if viewModel.apps.isEmpty {
                                viewModel.importMobileConfig(from: url)
                            } else {
                                pendingImportURL = url
                                showImportConfirmation = true
                            }
                        }
                    }
                }
                Button("Export") {
                    showExportSheet = true
                }
                .disabled(viewModel.apps.isEmpty)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportConfigSheet(viewModel: viewModel)
                .frame(width: 400)
        }
        .confirmationDialog("Import Options", isPresented: $showImportConfirmation, titleVisibility: .visible) {
            Button("Clear and Import", role: .destructive) {
                if let url = pendingImportURL {
                    viewModel.apps.removeAll()
                    viewModel.importMobileConfig(from: url)
                    pendingImportURL = nil
                }
            }
            Button("Keep Existing") {
                if let url = pendingImportURL {
                    viewModel.importMobileConfig(from: url)
                    pendingImportURL = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingImportURL = nil
            }
        }
    }

    @ViewBuilder
    private func selectableText(title: String, content: String, minHeight: CGFloat = 30) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
            TextEditor(text: .constant(content))
                .font(.body)
                .frame(minHeight: minHeight, maxHeight: minHeight)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    PPPCView()
}
