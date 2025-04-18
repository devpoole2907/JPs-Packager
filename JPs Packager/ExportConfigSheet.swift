//
//  ExportConfigSheet.swift
//  JPs Packager
//
//  Created by James Poole on 18/04/2025.
//

import SwiftUI

struct ExportConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PPPCViewModel
    @State private var identifier: String = UUID().uuidString.uppercased()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Organization")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $viewModel.exportOrganization)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Payload Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $viewModel.exportName)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Payload Identifier")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $identifier)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Payload Description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
