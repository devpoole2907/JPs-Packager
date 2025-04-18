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

                List(selection: $selectedAppID) {
                    ForEach(viewModel.apps) { app in
                        HStack {
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                            Text(app.displayName)
                        }
                        .tag(app.id)          // tag with UUID
                    }
                }
                .listStyle(.sidebar)
                .onDrop(of: [.fileURL], isTargeted: $viewModel.dropTargeted) { providers in
                    viewModel.handleDrop(providers: providers)
                }
            }
        } detail: {
            if let app = selectedApp {
                PPPCDetailView(app: app, permissionsExpanded: $permissionsExpanded)
            } else {
                Text("Drag apps on the left or select one")
                    .italic()
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 300)
        .navigationTitle("Privacy Preferences Policy Control Center")
        .toolbar {
            ToolbarItemGroup {
                Button("Import") {
                    // TODO: Implement import action
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
    @Published var dropTargeted = false
    @Published var exportOrganization = "JPs Packager"
    @Published var exportName = "PPPC Configuration"
    @Published var exportDescription = "Generated by JPs Packager"

    func addApp(from url: URL) {
        let bid = getBundleID(from: url)
        let req = getCodeRequirement(from: url)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let permissions = pppcServiceDisplayNames
            .keys
            .sorted { (pppcServiceDisplayNames[$0] ?? "") < (pppcServiceDisplayNames[$1] ?? "") }
            .map { PPPCPermission(service: $0) }
        let info = AppInfo(url: url, bundleID: bid, codeRequirement: req, icon: icon, permissions: permissions)
        if !apps.contains(info) {
            apps.append(info)
        }
    }

    func remove(app: AppInfo) {
        if let idx = apps.firstIndex(of: app) {
            apps.remove(at: idx)
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

    func exportMobileConfig(identifier: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "mobileconfig")!]
        panel.nameFieldStringValue = "\(self.exportName).mobileconfig"
        panel.canCreateDirectories = true

        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }

            var payloadContent: [[String: Any]] = []

            for app in self.apps {
                var servicesDict: [String: [[String: Any]]] = [:]

                for permission in app.permissions where permission.auth != .none {
                    let entry: [String: Any] = [
                        "Authorization": permission.auth.rawValue,
                        "Identifier": app.bundleID,
                        "IdentifierType": "bundleID",
                        "CodeRequirement": app.codeRequirement,
                        "Comment": permission.comment
                    ]

                    servicesDict[permission.service, default: []].append(entry)
                }

                let payloadUUID = UUID().uuidString.uppercased()
                let payload: [String: Any] = [
                    "PayloadDescription": "Privacy Preferences Policy Control for \(app.displayName)",
                    "PayloadDisplayName": "\(app.displayName) Permissions",
                    "PayloadIdentifier": UUID().uuidString,
                    "PayloadOrganization": "JPs Packager",
                    "PayloadType": "com.apple.TCC.configuration-profile-policy",
                    "PayloadUUID": payloadUUID,
                    "PayloadVersion": 1,
                    "Services": servicesDict
                ]

                payloadContent.append(payload)
            }

            let profile: [String: Any] = [
                "PayloadContent": payloadContent,
                "PayloadDescription": self.exportDescription,
                "PayloadDisplayName": self.exportName,
                "PayloadIdentifier": identifier,
                "PayloadOrganization": self.exportOrganization,
                "PayloadScope": "System",
                "PayloadType": "Configuration",
                "PayloadUUID": UUID().uuidString,
                "PayloadVersion": 1
            ]

            do {
                let data = try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
                try data.write(to: url)
            } catch {
                print("Failed to write mobileconfig: \(error)")
            }
        }
    }
}

struct PPPCDetailView: View {
    @ObservedObject var app: AppInfo
    @Binding var permissionsExpanded: Bool

    var body: some View {
        VStack(alignment: .leading) {
            
            HStack(alignment: .center, spacing: 12) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .cornerRadius(12)

                Text(app.displayName)
                    .font(.largeTitle)
                    .bold()
            }.padding()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 8) {
                    selectableText(title: "App Path:", content: app.url.path)
                    selectableText(title: "Bundle ID:", content: app.bundleID)
                    selectableText(title: "Code Requirement:", content: app.codeRequirement)

                    DisclosureGroup("Permissions", isExpanded: $permissionsExpanded) {
                        ForEach(app.permissions.indices, id: \.self) { idx in
                            HStack {
                                Text(app.permissions[idx].displayName)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Picker("", selection: $app.permissions[idx].auth) {
                                    ForEach(PPPCAuth.allCases) { auth in
                                        Text(auth.displayName).tag(auth)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 250)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                        }
                    }
                    .font(.headline)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectableText(title: String, content: String, minHeight: CGFloat = 30) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
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

struct ExportConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PPPCViewModel
    @State private var identifier: String = UUID().uuidString.uppercased()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Organization")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("", text: $viewModel.exportOrganization)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Payload Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("", text: $viewModel.exportName)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Payload Identifier")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("", text: $identifier)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Payload Description")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("", text: $viewModel.exportDescription)
            }

            HStack {
                Spacer()
                Button("Cancel", action: { dismiss() })
                Button("Export") {
                    viewModel.exportMobileConfig(identifier: identifier)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top)
        }
        .padding()
    }
}
