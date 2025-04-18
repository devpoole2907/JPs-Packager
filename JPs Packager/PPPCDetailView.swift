//
//  PPPCDetailView.swift
//  JPs Packager
//
//  Created by James Poole on 18/04/2025.
//

import SwiftUI

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
                    selectableText(title: "Code Requirement:", content: app.codeRequirement, minHeight: 60)

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
                .foregroundStyle(.secondary)
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
