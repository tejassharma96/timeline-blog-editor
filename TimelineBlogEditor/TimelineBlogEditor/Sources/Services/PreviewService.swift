import Foundation
import AppKit

/// Service for running Jekyll preview server
@MainActor
final class PreviewService: ObservableObject {

    enum PreviewState: Equatable {
        case idle
        case starting
        case running(url: URL)
        case error(String)
    }

    @Published var state: PreviewState = .idle

    private var process: Process?
    private var outputPipe: Pipe?
    private var blogDirectoryURL: URL?

    /// The default Jekyll server URL
    private let defaultPort = 4000

    /// Starts the Jekyll preview server
    func startPreview(blogDirectory: URL) async {
        // Stop any existing preview
        stopPreview()

        self.blogDirectoryURL = blogDirectory
        state = .starting

        // First run bundle install, then jekyll serve
        do {
            // Check if bundle install is needed by trying to run jekyll directly
            try await runJekyllServe(in: blogDirectory)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Stops the Jekyll preview server
    func stopPreview() {
        if let process = process, process.isRunning {
            process.terminate()

            // Also kill any child processes (jekyll spawns ruby)
            let killTask = Process()
            killTask.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            killTask.arguments = ["-f", "jekyll serve"]
            try? killTask.run()
        }
        process = nil
        outputPipe = nil
        state = .idle
    }

    /// Opens the preview URL in the default browser
    func openInBrowser() {
        guard case .running(let url) = state else { return }
        NSWorkspace.shared.open(url)
    }

    private func runJekyllServe(in directory: URL) async throws {
        let process = Process()
        self.process = process

        // Use shell to run bundle exec jekyll serve
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "cd '\(directory.path)' && bundle exec jekyll serve 2>&1"]
        process.currentDirectoryURL = directory

        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["LANG"] = "en_US.UTF-8"
        process.environment = environment

        let pipe = Pipe()
        self.outputPipe = pipe
        process.standardOutput = pipe
        process.standardError = pipe

        // Handle output asynchronously
        let handle = pipe.fileHandleForReading

        try process.run()

        // Monitor output for server start
        Task {
            await monitorOutput(handle: handle, directory: directory)
        }
    }

    private func monitorOutput(handle: FileHandle, directory: URL) async {
        var serverStarted = false
        var accumulatedOutput = ""

        // Read config to get baseurl
        let configURL = directory.appendingPathComponent("_config.yml")
        var baseurl = ""
        if let configContent = try? String(contentsOf: configURL, encoding: .utf8) {
            // Simple parsing for baseurl
            for line in configContent.components(separatedBy: .newlines) {
                if line.hasPrefix("baseurl:") {
                    let value = line.replacingOccurrences(of: "baseurl:", with: "").trimmingCharacters(in: .whitespaces)
                    baseurl = value.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
                    break
                }
            }
        }

        // Read output in chunks
        while let process = self.process, process.isRunning || handle.availableData.count > 0 {
            let data = handle.availableData
            if data.isEmpty {
                try? await Task.sleep(for: .milliseconds(100))
                continue
            }

            if let output = String(data: data, encoding: .utf8) {
                accumulatedOutput += output
                print("Jekyll output: \(output)") // Debug logging

                // Check for server address in output
                if !serverStarted && output.contains("Server address:") {
                    // Extract URL or use default
                    if let range = output.range(of: "Server address: ") {
                        let urlStart = output[range.upperBound...]
                        if let endRange = urlStart.range(of: "\n") ?? urlStart.range(of: " ") {
                            let urlString = String(urlStart[..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                            if let url = URL(string: urlString) {
                                await MainActor.run {
                                    self.state = .running(url: url)
                                }
                                serverStarted = true

                                // Auto-open in browser after a short delay
                                try? await Task.sleep(for: .seconds(1))
                                await MainActor.run {
                                    self.openInBrowser()
                                }
                            }
                        }
                    }

                    // Fallback to default URL
                    if !serverStarted {
                        let urlString = "http://127.0.0.1:\(defaultPort)\(baseurl)/"
                        if let url = URL(string: urlString) {
                            await MainActor.run {
                                self.state = .running(url: url)
                            }
                            serverStarted = true

                            try? await Task.sleep(for: .seconds(1))
                            await MainActor.run {
                                self.openInBrowser()
                            }
                        }
                    }
                }

                // Check for errors
                if output.contains("Error:") || output.contains("error:") || output.contains("Could not find") {
                    if !serverStarted {
                        await MainActor.run {
                            // Check if it's a bundle install needed error
                            if accumulatedOutput.contains("Could not find") || accumulatedOutput.contains("bundle install") {
                                self.state = .error("Bundle install may be needed. Try running 'bundle install' in the blog directory.")
                            } else {
                                self.state = .error("Jekyll error. Check console for details.")
                            }
                        }
                    }
                }
            }
        }

        // Process ended
        if !serverStarted {
            await MainActor.run {
                if case .starting = self.state {
                    self.state = .error("Jekyll server stopped unexpectedly")
                }
            }
        }
    }

    deinit {
        // Clean up on dealloc - terminate process synchronously
        if let process = process, process.isRunning {
            process.terminate()
        }
    }
}
