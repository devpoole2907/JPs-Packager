//
//  LogsView.swift
//  JPs Packager
//
//  Created by James Poole on 09/04/2025.
//
import SwiftUI

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
