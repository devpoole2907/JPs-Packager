//
//  AboutView.swift
//  JPs Packager
//
//  Created by James Poole on 09/04/2025.
//
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Created by James Poole, 2025")
                .font(.title2)
                .padding(.bottom, 4)

            Link("View on GitHub", destination: URL(string: "https://github.com/devpoole2907/JPs-Packager")!)
                .font(.headline)

            Spacer()
        }
        .padding()
        .navigationTitle("About")
    }
}
