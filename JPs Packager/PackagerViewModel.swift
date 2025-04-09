//
//  PackagerViewModel.swift
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
